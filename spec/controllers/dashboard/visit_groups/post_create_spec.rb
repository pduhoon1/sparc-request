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

require 'rails_helper'

RSpec.describe Dashboard::VisitGroupsController do
  describe '#create' do
    let!(:logged_in_user) { create(:identity) }

    context 'users with authorization' do
      before :each do
        log_in_dashboard_identity(obj: logged_in_user)

        org       = create(:organization)
                    create(:super_user, organization: org, identity: logged_in_user)
        @protocol = create(:protocol_federally_funded, primary_pi: logged_in_user)
        @sr       = create(:service_request_without_validations, protocol: @protocol)
        @ssr      = create(:sub_service_request, service_request: @sr, organization: org)
        @arm      = create(:arm, protocol: @protocol)

        @valid_vg_params = {
          service_request_id: @sr.id,
          sub_service_request_id: @ssr.id,
          visit_group: { 
            arm_id: @arm.id,
            name: 'Visit Me',
            position: 1,
            day: 1,
            window_before: 0,
            window_after: 0
          }
        }

        @invalid_vg_params = {
          service_request_id: @sr.id,
          sub_service_request_id: @ssr.id,
          visit_group: {
            arm_id: @arm.id,
            name: 'Visit Me',
            position: 1,
            day: 'asd',
            window_before: 0,
            window_after: 0
          }
        }
      end

      it 'should assign @service_request' do
        post :create, params: @valid_vg_params, xhr: true

        expect(assigns(:service_request)).to eq(@sr)
      end

      it 'should assign @sub_service_request' do
        post :create, params: @valid_vg_params, xhr: true

        expect(assigns(:sub_service_request)).to eq(@ssr)
      end

      it 'should assign @arm' do
        post :create, params: @valid_vg_params, xhr: true
        expect(assigns(:arm)).to eq(@arm)
      end

      context 'visit group is valid' do
        it 'should create visit group' do
          expect{
            post :create, params: @valid_vg_params, xhr: true
          }.to change(VisitGroup, :count).by 1
        end

        it 'should not assign @errors' do
          post :create, params: @valid_vg_params, xhr: true

          expect(assigns(:errors)).to_not be
        end
      end

      context 'visit group is invalid' do
        it 'should not create visit group' do
          expect{
            post :create, params: @invalid_vg_params, xhr: true
          }.to_not change(VisitGroup, :count)
        end

        it 'should assign @errors' do
          post :create, params: @invalid_vg_params, xhr: true

          expect(assigns(:errors)).to be
        end
      end

      it 'should render template' do
        post :create, params: @valid_vg_params, xhr: true

        expect(controller).to render_template(:create)
      end

      it 'should respond ok' do
        post :create, params: @valid_vg_params, xhr: true

        expect(controller).to respond_with(:ok)          
      end
    end

    context 'users without authorization' do
      before :each do
        log_in_dashboard_identity(obj: logged_in_user)

        org       = create(:organization)
        @protocol = create(:protocol_federally_funded, primary_pi: logged_in_user)
        @sr       = create(:service_request_without_validations, protocol: @protocol)
        @ssr      = create(:sub_service_request, service_request: @sr, organization: org)
        @arm      = create(:arm, protocol: @protocol)
        
        post :create, params: {
          service_request_id: @sr.id,
          sub_service_request_id: @ssr.id,
          visit_group: {
            arm_id: @arm.id,
            name: 'Visit Me',
            position: 1,
            day: 1,
            window_before: 0,
            window_after: 0
          }
        }, xhr: true
      end

      it 'should not assign variables' do
        expect(assigns(:protocol)).to eq(nil)
        expect(assigns(:service_request)).to eq(nil)
        expect(assigns(:sub_service_request)).to eq(nil)
        expect(assigns(:visit_group)).to eq(nil)
      end

      it { is_expected.to redirect_to(dashboard_root_path) }

      it { is_expected.to respond_with(302) }
    end
  end
end
