# Copyright © 2011-2018 MUSC Foundation for Research Development~
# All rights reserved.~

# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:~

# 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.~

# 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following~
# disclaimer in the documentation and/or other materials provided with the distribution.~

# 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products~
# derived from this software without specific prior written permission.~

# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,~
# BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT~
# SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL~
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS~
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR~
# TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.~

require "rails_helper"

RSpec.describe Dashboard::SubsidiesController do
  describe "POST #create" do
    context 'User is an admin and percent subsidy is greater than 0' do
      before(:each) do
        @current_user = build_stubbed(:identity)
        log_in_dashboard_identity(obj: @current_user)
        @protocol        = create(:protocol_without_validations,
                                  primary_pi: @current_user)
        @organization    = create(:organization)
        @subsidy_map     = create(:subsidy_map,
                                  default_percentage: 0,
                                  max_percentage: 10.0,
                                  organization: @organization)
        @service_request = create(:service_request_without_validations,
                                  protocol: @protocol)
        @ssr             = create(:sub_service_request_without_validations,
                                  service_request: @service_request,
                                  organization: @organization,
                                  status: 'draft')
        post :create, params: { admin: 'true', pending_subsidy: { sub_service_request_id: @ssr.id, percent_subsidy: "50.00", pi_contribution: "100.00" }, format: :js }, xhr: true
      end

      it { is_expected.to render_template "dashboard/subsidies/create" }

      it 'should respond ok' do
        expect(controller).to respond_with(:ok)
      end

      it 'should assign @subsidy without pi contribution' do
        expect(assigns(:subsidy).percent_subsidy).to eq(0.5)
        expect(assigns(:subsidy).pi_contribution).to eq(0)
      end

      it 'should not assign @errors' do
        expect(assigns(:errors)).to be_nil
      end

      it 'should save @subsidy without validations' do
        expect(Subsidy.count).to eq(1)
      end
    end

    context 'User is not an admin' do
      context 'Subsidy is valid' do
        before(:each) do
          @current_user = build_stubbed(:identity)
          @other_user = create(:identity)
          log_in_dashboard_identity(obj: @current_user)
          @protocol        = create(:protocol_without_validations,
                                    primary_pi: @other_user)
          @organization    = create(:organization)
          @subsidy_map     = create(:subsidy_map,
                                    default_percentage: 0,
                                    max_percentage: 10.0,
                                    organization: @organization)
          @service_request = create(:service_request_without_validations,
                                    protocol: @protocol)
          @ssr             = create(:sub_service_request_without_validations,
                                    service_request: @service_request,
                                    organization: @organization,
                                    status: 'draft')
          post :create, params: { admin: 'false', pending_subsidy: { sub_service_request_id: @ssr.id, percent_subsidy: "9.00", pi_contribution: "100.00" }, format: :js }, xhr: true
        end

        it 'should respond found' do
          expect(controller).to respond_with(:found)
        end

        it 'should assign @subsidy without pi contribution' do
          expect(assigns(:subsidy).percent_subsidy).to eq(0.09)
          expect(assigns(:subsidy).pi_contribution).to eq(0)
        end

        it 'should not assign @errors' do
          expect(assigns(:errors)).to be_nil
        end

        it 'should redirect to the dashboard SSR path for @ssr' do
          expect(response).to redirect_to(dashboard_sub_service_request_path(@ssr, format: :js))
        end

        it 'should save @subsidy with validations' do
          expect(Subsidy.count).to eq(1)
          expect(assigns(:subsidy).valid?).to eq(true)
        end
      end

      context 'Subsidy is not valid' do
        before(:each) do
          @current_user = build_stubbed(:identity)
          @other_user = create(:identity)
          log_in_dashboard_identity(obj: @current_user)
          @protocol        = create(:protocol_without_validations,
                                    primary_pi: @other_user)
          @organization    = create(:organization)
          @subsidy_map     = create(:subsidy_map,
                                    default_percentage: 0,
                                    max_percentage: 10.0,
                                    organization: @organization)
          @service_request = create(:service_request_without_validations,
                                    protocol: @protocol)
          @ssr             = create(:sub_service_request_without_validations,
                                    service_request: @service_request,
                                    organization: @organization,
                                    status: 'draft')
          post :create, params: { admin: 'false', pending_subsidy: { sub_service_request_id: @ssr.id, percent_subsidy: "50.00", pi_contribution: "100.00" }, format: :js }, xhr: true
        end

        it { is_expected.to render_template "dashboard/subsidies/create" }

        it 'should respond ok' do
          expect(controller).to respond_with(:ok)
        end

        it 'should not save @subsidy' do
          expect(Subsidy.count).to eq(0)
        end

        it 'should assign @errors' do
          expect(assigns(:errors)).to be
        end
      end
    end
  end
end