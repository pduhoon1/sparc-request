# Copyright © 2011-2017 MUSC Foundation for Research Development
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

class CatalogManager::ServiceProvidersController < ApplicationController

  def create
    ServiceProvider.create(service_provider_params)
  end

  def destroy
    ServiceProvider.find_by(service_provider_params).destroy
  end

  def update
    cm = ServiceProvider.find_by(identity_id: service_provider_params[:identity_id], organization_id: service_provider_params[:organization_id])
    primary_contact = service_provider_params[:is_primary_contact].nil? ? cm.is_primary_contact : service_provider_params[:is_primary_contact] == 'true'
    hold_emails = service_provider_params[:hold_emails].nil? ? cm.hold_emails : service_provider_params[:hold_emails] == 'true'
    cm.update_attributes(is_primary_contact: primary_contact, hold_emails: hold_emails)
  end

  private

  def service_provider_params
    params.require(:service_provider).permit(
      :identity_id,
      :organization_id,
      :is_primary_contact,
      :hold_emails)
  end
end