require 'generate_request_grant_billing_pdf'

class ServiceRequestsController < ApplicationController
  before_filter :initialize_service_request, :except => [:approve_changes]
  before_filter :authorize_identity, :except => [:approve_changes, :show]
  before_filter :authenticate_identity!, :except => [:catalog, :add_service, :remove_service, :ask_a_question, :feedback]
  layout false, :only => [:ask_a_question, :feedback]
  respond_to :js, :json, :html

  def show
    @protocol = @service_request.protocol
    @service_list = @service_request.service_list

    # TODO: this gives an error in the spec tests, because they think
    # it's trying to render html instead of xlsx
    #
    #   render xlsx: "show", filename: "service_request_#{@service_request.id}", disposition: "inline"
    #
    # So I did this instead, but I don't know if it's right:
    #
    respond_to do |format|
      format.xlsx do
        render xlsx: "show", filename: "service_request_#{@service_request.id}", disposition: "inline"
      end
    end
  end

  def navigate
    errors = [] 
    # need to save and navigate to the right page

    #### add logic to save data
    referrer = request.referrer.split('/').last
    
    #### convert dollars to cents for subsidy
    if params[:service_request] && params[:service_request][:sub_service_requests_attributes]
      params[:service_request][:sub_service_requests_attributes].each do |key, values|
        dollars = values[:subsidy_attributes][:pi_contribution]

        if dollars.blank? # we don't want to create a subsidy if it's blank
          values.delete(:subsidy_attributes) 
          ssr = @service_request.sub_service_requests.find values[:id]
          ssr.subsidy.delete if ssr.subsidy
        else
          values[:subsidy_attributes][:pi_contribution] = Service.dollars_to_cents(dollars)
        end
      end
    end

    @service_request.update_attributes(params[:service_request])

    #### save/update documents if we have them
    process_ssr_organization_ids = params[:process_ssr_organization_ids]
    document_grouping_id = params[:document_grouping_id]
    document = params[:document]

    if document_grouping_id and not process_ssr_organization_ids
      # we are deleting this grouping, this is essentially the same as clicking delete next to a grouping
      document_grouping = @service_request.document_groupings.find document_grouping_id
      document_grouping.destroy
    elsif process_ssr_organization_ids and (!document or params[:doc_type].empty?) and not document_grouping_id # new document but we didn't provide either the document or document type
      # we did not provide a document
      #[{:visit_count=>["You must specify the estimated total number of visits (greater than zero) before continuing."], :subject_count=>["You must specify the estimated total number of subjects before continuing."]}]
      doc_errors = {}
      doc_errors[:document] = ["You must select a document to upload"] if !document
      doc_errors[:doc_type] = ["You must provide a document type"] if params[:doc_type].empty?
      errors << doc_errors
    elsif process_ssr_organization_ids and not document_grouping_id
      # we have a new grouping
      document_grouping = @service_request.document_groupings.create
      process_ssr_organization_ids.each do |org_id|
        sub_service_request = @service_request.sub_service_requests.find_by_organization_id org_id.to_i
        sub_service_request.documents.create :document => document, :doc_type => params[:doc_type], :doc_type_other => params[:doc_type_other], :document_grouping_id => document_grouping.id
        sub_service_request.save
      end
    elsif process_ssr_organization_ids and document_grouping_id
      # we need to update an existing grouping
      document_grouping = @service_request.document_groupings.find document_grouping_id
      grouping_org_ids = document_grouping.documents.map{|d| d.sub_service_request.organization_id.to_s}
      to_delete = grouping_org_ids - process_ssr_organization_ids
      to_add = process_ssr_organization_ids - grouping_org_ids
      to_update = process_ssr_organization_ids & grouping_org_ids
      to_delete.each do |org_id|
        document_grouping.documents.each do |doc|
          doc.destroy if doc.organization.id == org_id.to_i
        end

        document_grouping.reload
        document_grouping.destroy if document_grouping.documents.empty?
      end
      
      to_add.each do |org_id|
        if document and not params[:doc_type].empty?
          sub_service_request = @service_request.sub_service_requests.find_or_create_by_organization_id :organization_id => org_id.to_i
          sub_service_request.documents.create :document => document, :doc_type => params[:doc_type], :doc_type_other => params[:doc_type_other], :document_grouping_id => document_grouping.id
          sub_service_request.save
        else
          doc_errors = {}
          doc_errors[:document] = ["You must select a document to upload"] if !document
          doc_errors[:doc_type] = ["You must provide a document type"] if params[:doc_type].empty?
          errors << doc_errors
        end
      end

      # updating sub_service_request documents should create a new grouping unless the grouping only contains documents for that sub_service_request
      to_update.each do |org_id|
        if params[:doc_type].empty?
          errors << {:document_upload => ["You must provide a document type"]}
        else
          if @sub_service_request.nil? or document_grouping.documents.size == 1 # we either don't have a sub_service_request or the only document in this group is the one we are updating
            document_grouping.documents.each do |doc|
              new_doc = document ? document : doc.document # use the old document
              doc.update_attributes(:document => new_doc, :doc_type => params[:doc_type], :doc_type_other => params[:doc_type_other]) if doc.organization.id == org_id.to_i
            end
          else # we have a sub_service_request and the document count is greater than 1 so we need to do some special stuff
            new_document_grouping = @service_request.document_groupings.create
            document_grouping.documents.each do |doc|
              new_doc = document ? document : doc.document # use the old document
              doc.update_attributes({:document => new_doc, :doc_type => params[:doc_type], :doc_type_other => params[:doc_type_other], :document_grouping_id => new_document_grouping.id}) if doc.organization.id == @sub_service_request.id
            end
          end
        end
      end
    end

    # end document saving stuff

    location = params["location"]
    additional_params = request.referrer.split('/').last.split('?').size == 2 ? "?" + request.referrer.split('/').last.split('?').last : nil
    validates = params["validates"]

    if (@validation_groups[location].nil? or @validation_groups[location].map{|vg| @service_request.group_valid? vg.to_sym}.all?) and (validates.blank? or @service_request.group_valid? validates.to_sym) and errors.empty?
      @service_request.save(:validate => false)
      redirect_to "/service_requests/#{@service_request.id}/#{location}#{additional_params}"
    else
      if @validation_groups[location]
        @validation_groups[location].each do |vg| 
          errors << @service_request.grouped_errors[vg.to_sym].messages unless @service_request.grouped_errors[vg.to_sym].messages.empty?
        end
      end

      unless validates.blank?
        errors << @service_request.grouped_errors[validates.to_sym].messages unless @service_request.grouped_errors[validates.to_sym].empty?
      end

      session[:errors] = errors.compact.flatten.first # TODO I DON'T LIKE THIS AT ALL
      redirect_to :back
    end
  end

  # service request wizard pages

  def catalog
    if session['sub_service_request_id']
      @institutions = @sub_service_request.organization.parents.select{|x| x.type == 'Institution'}
    else
      @institutions = Institution.order('`order`')
    end
  end
  
  def protocol
    @service_request.update_attribute(:service_requester_id, current_user.id) if @service_request.service_requester_id.nil?
    
    @studies = @sub_service_request.nil? ? current_user.studies : @service_request.protocol.type == "Study" ? [@service_request.protocol] : []
    @projects = @sub_service_request.nil? ? current_user.projects : @service_request.protocol.type == "Project" ? [@service_request.protocol] : []

    if session[:saved_study_id]
      @service_request.protocol = Study.find session[:saved_study_id]
      session.delete :saved_study_id
    elsif session[:saved_project_id]
      @service_request.protocol = Project.find session[:saved_project_id]
      session.delete :saved_project_id
    end
  end
  
  def service_details
  end

  def service_calendar
    if @service_request.arms.blank?
      redirect_to "/service_requests/#{@service_request.id}/#{@forward}"
    else
      #use session so we know what page to show when tabs are switched
      session[:service_calendar_pages] = params[:pages] if params[:pages]

      # TODO: why is @page not set here?  if it's not supposed to be set
      # then there should be a comment as to why it's set in #review but
      # not here

      @service_request.arms.each do |arm|
        #check each ARM for line_items_visits (in other words, it's a new arm)
        if arm.line_items_visits.empty?
          #Create missing line_items_visits
          @service_request.per_patient_per_visit_line_items.each do |line_item|
            arm.create_line_items_visit(line_item)
          end
        else
          #Check to see if ARM has been modified...
          arm.line_items_visits.each do |liv|
            #Update subject counts under certain conditions
            if @service_request.status == 'first_draft' or liv.subject_count.nil? or liv.subject_count > arm.subject_count
              liv.update_attribute(:subject_count, arm.subject_count)
            end
            # if arm.visit_count > liv.visits.count
            #   liv.create_visits
            # end
          end
          #Arm.visit_count has benn increased, so create new visit group, and populate the visits
          if arm.visit_count > arm.visit_groups.count
            arm.create_visit_group until arm.visit_count == arm.visit_groups.count
          end
          #Arm.visit_count has been decreased, destroy visit group (and visits)
          if arm.visit_count < arm.visit_groups.count
            arm.visit_groups.last.destroy until arm.visit_count == arm.visit_groups.count
          end
        end
      end
    end
  end

  def calendar_totals
    if @service_request.arms.blank?
      @back = 'service_details'
    end
  end

  def service_subsidy
    @subsidies = []
    @service_request.sub_service_requests.each do |ssr|
      if ssr.subsidy
        # we already have a subsidy; add it to the list
        @subsidies << ssr.subsidy
      elsif ssr.eligible_for_subsidy?
        # we don't have a subsidy yet; add it to the list but don't save
        # it yet
        # TODO: is it a good idea to modify this SubServiceRequest like
        # this without saving it to the database?
        ssr.build_subsidy
        @subsidies << ssr.subsidy
      end
    end
  end
  
  def document_management
    @service_list = @service_request.service_list
  end
  
  def review
    arm_id = params[:arm_id].to_s if params[:arm_id]
    page = params[:page] if params[:page]
    session[:service_calendar_pages] = params[:pages] if params[:pages]
    session[:service_calendar_pages][arm_id] = page if page && arm_id

    @service_list = @service_request.service_list
    @protocol = @service_request.protocol
    
    # Reset all the page numbers to 1 at the start of the review request
    # step.
    @pages = {}
    @service_request.arms.each do |arm|
      @pages[arm.id] = 1
    end

    @tab = 'pricing'
  end

  def obtain_research_pricing
    # TODO: refactor into the ServiceRequest model
    @service_request.update_attribute(:status, 'obtain_research_pricing')
    @service_request.update_attribute(:submitted_at, Time.now)
    next_ssr_id = @service_request.protocol.next_ssr_id || 1
    @service_request.sub_service_requests.each do |ssr|
      ssr.update_attribute(:status, 'obtain_research_pricing')
      ssr.update_attribute(:ssr_id, "%04d" % next_ssr_id) unless ssr.ssr_id
      next_ssr_id += 1
    end
    
    @protocol = @service_request.protocol
    @service_list = @service_request.service_list

    @protocol.update_attribute(:next_ssr_id, next_ssr_id)

    # Does an approval need to be created, check that the user submitting has approve rights
    if @protocol.project_roles.detect{|pr| pr.identity_id == current_user.id}.project_rights != "approve"
      approval = @service_request.approvals.create
    else
      approval = false
    end

    # generate the excel for this service request
    # xls = render_to_string :action => 'show', :formats => [:xlsx]
    xls = render_to_string :action => 'show', :formats => [:xlsx]

    # send e-mail to all folks with view and above
    @protocol.project_roles.each do |project_role|
      next if project_role.project_rights == 'none'
      Notifier.notify_user(project_role, @service_request, xls, approval).deliver
    end

    # send e-mail to admins and service providers
    if @sub_service_request # only notify the submission e-mails for this sub service request
      @sub_service_request.organization.submission_emails_lookup.each do |submission_email|
        Notifier.notify_admin(@service_request, submission_email.email, xls).deliver
      end
    else # notify the submission e-mails for the service request
      @service_request.sub_service_requests.each do |sub_service_request|
        sub_service_request.organization.submission_emails_lookup.each do |submission_email|
          Notifier.notify_admin(@service_request, submission_email.email, xls).deliver
        end
      end
    end

    # send e-mail to all service providers
    if @sub_service_request # only notify the service providers for this sub service request
      @sub_service_request.organization.service_providers.where("(`service_providers`.`hold_emails` != 1 OR `service_providers`.`hold_emails` IS NULL)").each do |service_provider|
        attachments = {}
        attachments["service_request_#{@service_request.id}.xls"] = xls

        #TODO this is not very multi-institutional
        # generate the muha pdf if it's required
        if @sub_service_request.organization.tag_list.include? 'muha'
          request_for_grant_billing_form = RequestGrantBillingPdf.generate_pdf @service_request
          attachments["request_for_grant_billing_#{@service_request.id}.pdf"] = request_for_grant_billing_form
        end

        Notifier.notify_service_provider(service_provider, @service_request, attachments).deliver
      end
    else
      @service_request.sub_service_requests.each do |sub_service_request|
        sub_service_request.organization.service_providers.where("(`service_providers`.`hold_emails` != 1 OR `service_providers`.`hold_emails` IS NULL)").each do |service_provider|
          attachments = {}
          attachments["service_request_#{@service_request.id}.xls"] = xls

          #TODO this is not very multi-institutional
          # generate the muha pdf if it's required
          if sub_service_request.organization.tag_list.include? 'muha'
            request_for_grant_billing_form = RequestGrantBillingPdf.generate_pdf @service_request
            attachments["request_for_grant_billing_#{@service_request.id}.pdf"] = request_for_grant_billing_form
          end

          Notifier.notify_service_provider(service_provider, @service_request, attachments).deliver
        end
      end
    end
    
    render :formats => [:html]
  end

  def confirmation
    # TODO: refactor into the ServiceRequest model
    @service_request.update_attribute(:status, 'submitted')
    @service_request.update_attribute(:submitted_at, Time.now)
    next_ssr_id = @service_request.protocol.next_ssr_id || 1
    @service_request.sub_service_requests.each do |ssr|
      ssr.update_attribute(:status, 'submitted')
      ssr.update_attribute(:ssr_id, "%04d" % next_ssr_id) unless ssr.ssr_id
      next_ssr_id += 1
    end
    
    @protocol = @service_request.protocol
    @service_list = @service_request.service_list

    @protocol.update_attribute(:next_ssr_id, next_ssr_id)

    # Does an approval need to be created, check that the user submitting has approve rights
    if @protocol.project_roles.detect{|pr| pr.identity_id == current_user.id}.project_rights != "approve"
      approval = @service_request.approvals.create
    else
      approval = false
    end

    # generate the excel for this service request
    # xls = render_to_string :action => 'show', :formats => [:xlsx]
    xls = render_to_string :action => 'show', :formats => [:xlsx]

    # send e-mail to all folks with view and above
    @protocol.project_roles.each do |project_role|
      next if project_role.project_rights == 'none'
      Notifier.notify_user(project_role, @service_request, xls, approval).deliver
    end

    # send e-mail to admins and service providers
    if @sub_service_request # only notify the submission e-mails for this sub service request
      @sub_service_request.organization.submission_emails_lookup.each do |submission_email|
        Notifier.notify_admin(@service_request, submission_email.email, xls).deliver
      end
    else # notify the submission e-mails for the service request
      @service_request.sub_service_requests.each do |sub_service_request|
        sub_service_request.organization.submission_emails_lookup.each do |submission_email|
          Notifier.notify_admin(@service_request, submission_email.email, xls).deliver
        end
      end
    end

    # send e-mail to all service providers
    if @sub_service_request # only notify the service providers for this sub service request
      @sub_service_request.organization.service_providers.where("(`service_providers`.`hold_emails` != 1 OR `service_providers`.`hold_emails` IS NULL)").each do |service_provider|
        attachments = {}
        attachments["service_request_#{@service_request.id}.xls"] = xls

        #TODO this is not very multi-institutional
        # generate the muha pdf if it's required
        if @sub_service_request.organization.tag_list.include? 'muha'
          request_for_grant_billing_form = RequestGrantBillingPdf.generate_pdf @service_request
          attachments["request_for_grant_billing_#{@service_request.id}.pdf"] = request_for_grant_billing_form
        end

        Notifier.notify_service_provider(service_provider, @service_request, attachments).deliver
      end
    else
      @service_request.sub_service_requests.each do |sub_service_request|
        sub_service_request.organization.service_providers.where("(`service_providers`.`hold_emails` != 1 OR `service_providers`.`hold_emails` IS NULL)").each do |service_provider|
          attachments = {}
          attachments["service_request_#{@service_request.id}.xls"] = xls

          #TODO this is not very multi-institutional
          # generate the muha pdf if it's required
          if sub_service_request.organization.tag_list.include? 'muha'
            request_for_grant_billing_form = RequestGrantBillingPdf.generate_pdf @service_request
            attachments["request_for_grant_billing_#{@service_request.id}.pdf"] = request_for_grant_billing_form
          end

          Notifier.notify_service_provider(service_provider, @service_request, attachments).deliver
        end
      end
    end
    
    render :formats => [:html]
  end

  def approve_changes
    @service_request = ServiceRequest.find params[:id]
    @approval = @service_request.approvals.where(:id => params[:approval_id]).first
    @previously_approved = true
 
    if @approval and @approval.identity.nil?
      @approval.update_attribute(:identity_id, current_user.id)
      @approval.update_attribute(:approval_date, Time.now)
      @previously_approved = false 
    end
  end

  def save_and_exit
    # TODO: refactor into the ServiceRequest model
    
    if @sub_service_request # if we are editing a sub service request we should just update it's status
      @sub_service_request.update_attribute(:status, 'draft')
    else
      @service_request.update_attribute(:status, 'draft')
      
      next_ssr_id = @service_request.protocol.next_ssr_id || 1
      @service_request.sub_service_requests.each do |ssr|
        ssr.update_attribute(:status, 'draft')
        ssr.update_attribute(:ssr_id, "%04d" % next_ssr_id) unless ssr.ssr_id
        next_ssr_id += 1
      end
      @service_request.protocol.update_attribute(:next_ssr_id, next_ssr_id)
    end

    redirect_to USER_PORTAL_LINK 
  end

  def refresh_service_calendar
    arm_id = params[:arm_id].to_s if params[:arm_id]
    @arm = Arm.find arm_id if arm_id
    page = params[:page] if params[:page]
    session[:service_calendar_pages] = params[:pages] if params[:pages]
    session[:service_calendar_pages][arm_id] = page if page && arm_id
    @pages = {}
    @service_request.arms.each do |arm|
      new_page = (session[:service_calendar_pages].nil?) ? 1 : session[:service_calendar_pages][arm.id.to_s].to_i
      @pages[arm.id] = @service_request.set_visit_page new_page, arm
    end
    @tab = 'pricing'
  end


  # methods only used by ajax requests

  def add_service
    id = params[:service_id].sub('service-', '').to_i
    @new_line_items = []
    existing_service_ids = @service_request.line_items.map(&:service_id)

    if existing_service_ids.include? id
      render :text => 'Service exists in line items' 
    else
      service = Service.find id

      unless service.is_one_time_fee?
        if @service_request.arms.empty?
          @service_request.arms.create(
              name: 'ARM 1',
              visit_count: 1,
              subject_count: 1)
        end
      end

      @new_line_items = @service_request.create_line_items_for_service(
          service: service,
          optional: true,
          existing_service_ids: existing_service_ids)

      # create sub_service_requests
      @service_request.reload
      @service_request.service_list.each do |org_id, values|
        line_items = values[:line_items]
        ssr = @service_request.sub_service_requests.find_or_create_by_organization_id :organization_id => org_id.to_i
        unless @service_request.status.nil? and !ssr.status.nil?
          ssr.update_attribute(:status, @service_request.status)
        end

        line_items.each do |li|
          li.update_attribute(:sub_service_request_id, ssr.id)
        end
      end
    end
  end

  def remove_service
    id = params[:line_item_id].sub('line_item-', '').to_i

    @line_item = @service_request.line_items.find(id)
    service = @line_item.service
    line_item_service_ids = @service_request.line_items.map(&:service_id)

    # look at related services and set them to optional
    # TODO POTENTIAL ISSUE: what if another service has the same related service
    service.related_services.each do |rs|
      if line_item_service_ids.include? rs.id
        @service_request.line_items.find_by_service_id(rs.id).update_attribute(:optional, true)
      end
    end

    @line_items.find_by_service_id(service.id).destroy
    @line_items.reload
    
    #@service_request = current_user.service_requests.find session[:service_request_id]
    @service_request = ServiceRequest.find session[:service_request_id]
    @page = request.referrer.split('/').last # we need for pages other than the catalog

    # clean up sub_service_requests
    @service_request.reload
    to_delete = @service_request.sub_service_requests.map(&:organization_id) - @service_request.service_list.keys
    to_delete.each do |org_id|
      @service_request.sub_service_requests.find_by_organization_id(org_id).destroy
    end

    # clean up arms
    @service_request.reload
    @service_request.arms.each do |arm|
      if arm.line_items_visits.empty?
        arm.destroy
      end
    end
  end

  def delete_documents
    # deletes a group of documents unless we are working with a sub_service_request
    grouping = @service_request.document_groupings.find params[:document_group_id]
    @tr_id = "#document_grouping_#{grouping.id}"

    if @sub_service_request.nil?
      grouping.destroy # destroys the grouping and the documents
    else
      grouping.documents.find_by_sub_service_request_id(@sub_service_request.id).destroy
      grouping.reload
      grouping.destroy if grouping.documents.empty?
    end
  end

  def edit_documents
    @grouping = @service_request.document_groupings.find params[:document_group_id]
    @service_list = @service_request.service_list
  end

  def ask_a_question
    from = params['question_email'] || 'no-reply@musc.edu'
    body = params['question_body'] || 'No question asked'

    question = Question.create :to => DEFAULT_MAIL_TO, :from => from, :body => body
    Notifier.ask_a_question(question).deliver
  end

  def feedback
    feedback = Feedback.new(params[:feedback])
    if feedback.save
      Notifier.provide_feedback(feedback).deliver
      render :nothing => true
    else
      respond_to do |format|
        format.js { render :status => 403, :json => feedback.errors.to_a.map {|k,v| "#{k.humanize} #{v}".rstrip + '.'} }
      end
    end
  end

  def select_calendar_row
    @line_items_visit = LineItemsVisit.find params[:line_items_visit_id]
    @service = @line_items_visit.line_item.service
    @line_items_visit.visits.each do |visit|
      visit.update_attributes(
          quantity:              @service.displayed_pricing_map.unit_minimum,
          research_billing_qty:  @service.displayed_pricing_map.unit_minimum,
          insurance_billing_qty: 0,
          effort_billing_qty:    0)
    end
    
    render :partial => 'update_service_calendar'
  end
  
  def unselect_calendar_row
    @line_items_visit = LineItemsVisit.find params[:line_items_visit_id]
    @line_items_visit.visits.each do |visit|
      visit.update_attributes({:quantity => 0, :research_billing_qty => 0, :insurance_billing_qty => 0, :effort_billing_qty => 0})
    end

    render :partial => 'update_service_calendar'
  end

  def select_calendar_column
    column_id = params[:column_id].to_i
    @arm = Arm.find params[:arm_id]

    @arm.line_items_visits.each do |liv|
      visit = liv.visits[column_id - 1] # columns start with 1 but visits array positions start at 0
      visit.update_attributes(
          quantity:              liv.line_item.service.displayed_pricing_map.unit_minimum,
          research_billing_qty:  liv.line_item.service.displayed_pricing_map.unit_minimum,
          insurance_billing_qty: 0,
          effort_billing_qty:    0)
    end
    
    render :partial => 'update_service_calendar'
  end
  
  def unselect_calendar_column
    column_id = params[:column_id].to_i
    @arm = Arm.find params[:arm_id]

    @arm.line_items_visits.each do |liv|
      visit = liv.visits[column_id - 1] # columns start with 1 but visits array positions start at 0
      visit.update_attributes({:quantity => 0, :research_billing_qty => 0, :insurance_billing_qty => 0, :effort_billing_qty => 0})
    end
    
    render :partial => 'update_service_calendar'
  end
end
