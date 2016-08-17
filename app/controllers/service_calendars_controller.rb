# Copyright © 2011 MUSC Foundation for Research Development
# All rights reserved.

# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

# 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

# 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following
# disclaimer in the documentation and/or other materials provided with the distribution.

# 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products
# derived from this software without specific prior written permission.

# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,
# BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
# SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
# TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

class ServiceCalendarsController < ApplicationController
  respond_to :html, :js
  layout false
  
  before_filter :initialize_service_request
  before_filter :authorize_identity

  def table
    @tab    = params[:tab]
    @review = params[:review] == 'true'
    @portal = params[:portal] == 'true'
    @merged = false

    setup_calendar_pages

    respond_to do |format|
      format.js
      format.html
    end
  end

  def merged_calendar
    @tab    = params[:tab]
    @review = params[:review] == 'true'
    @portal = params[:portal] == 'true'
    @merged = true

    setup_calendar_pages

    respond_to do |format|
      format.js
      format.html
    end
  end

  def view_full_calendar
    @tab              = 'calendar'
    @review           = false
    @portal           = true
    @merged           = true
    @protocol         = Protocol.find(params[:protocol_id])
    @service_request  = @protocol.any_service_requests_to_display?

    setup_calendar_pages

    respond_to do |format|
      format.js
      format.html
    end
  end

  def show_move_visits
    @arm = Arm.find( params[:arm_id] )
  end

  def move_visit_position
    arm       = Arm.find( params[:arm_id] )
    vg        = arm.visit_groups.find( params[:visit_group].to_i )

    if params[:position].blank?
      vg.move_to_bottom
    else
      vg.insert_at( params[:position].to_i - 1 )
    end
  end

  def toggle_calendar_row
    @line_items_visit     = LineItemsVisit.find(params[:line_items_visit_id])
    @service              = @line_items_visit.line_item.service if params[:check]
    @portal               = params[:portal] == 'true'

    @line_items_visit.visits.each do |visit|
      if params[:check]
        visit.update_attributes(quantity: @service.displayed_pricing_map.unit_minimum, research_billing_qty: @service.displayed_pricing_map.unit_minimum, insurance_billing_qty: 0, effort_billing_qty: 0)
      elsif params[:uncheck]
        visit.update_attributes(quantity: 0, research_billing_qty: 0, insurance_billing_qty: 0, effort_billing_qty: 0)
      end
    end

    # Update the sub service request only if we are not in dashboard; admin's actions should not affect the status
    unless @portal
      sub_service_request = @line_items_visit.line_item.sub_service_request
      sub_service_request.update_attribute(:status, "draft")
      sub_service_request.update_past_status(current_user)
      @service_request.update_attribute(:status, "draft")
    end

    render partial: 'update_service_calendar'
  end

  def toggle_calendar_column
    column_id = params[:column_id].to_i
    @arm      = Arm.find(params[:arm_id])
    @portal   = params[:portal] == 'true'

    @service_request.service_list(false).each do |_key, value|
      next unless @sub_service_request.nil? || @sub_service_request.organization.name == value[:process_ssr_organization_name]

      @arm.line_items_visits.each do |liv|
        next unless value[:line_items].include?(liv.line_item) && liv.line_item.sub_service_request.can_be_edited? && !liv.line_item.sub_service_request.is_complete?
        visit = liv.visits[column_id - 1] # columns start with 1 but visits array positions start at 0
        if params[:check]
          visit.update_attributes quantity: liv.line_item.service.displayed_pricing_map.unit_minimum, research_billing_qty: liv.line_item.service.displayed_pricing_map.unit_minimum, insurance_billing_qty: 0, effort_billing_qty: 0
        elsif params[:uncheck]
          visit.update_attributes quantity: 0, research_billing_qty: 0, insurance_billing_qty: 0, effort_billing_qty: 0
        end
      end
    end

    # Update the sub service request only if we are not in dashboard; admin's actions should not affect the status
    unless @portal
      @arm.line_items.map(&:sub_service_request).uniq.each do |ssr|
        next if @sub_service_request && ssr != @sub_service_request
        ssr.update_attribute(:status, "draft")
        ssr.update_past_status(current_user)
      end
      @service_request.update_attribute(:status, "draft")
    end

    render partial: 'update_service_calendar'
  end

  private

  def setup_calendar_pages
    @pages  = {}
    page    = params[:page] if params[:page]
    arm_id  = params[:arm_id] if params[:arm_id]
    @arm    = Arm.find(arm_id) if arm_id

    session[:service_calendar_pages]          = params[:pages] if params[:pages]
    session[:service_calendar_pages][arm_id]  = page if page && arm_id
    
    @service_request.arms.each do |arm|
      new_page        = (session[:service_calendar_pages].nil?) ? 1 : session[:service_calendar_pages][arm.id.to_s].to_i
      @pages[arm.id]  = @service_request.set_visit_page(new_page, arm)
    end
  end
end
