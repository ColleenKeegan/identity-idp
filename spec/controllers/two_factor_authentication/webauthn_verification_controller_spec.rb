require 'rails_helper'

describe TwoFactorAuthentication::WebauthnVerificationController do
  include WebAuthnHelper

  describe 'when not signed in' do
    describe 'GET show' do
      it 'redirects to root url' do
        get :show

        expect(response).to redirect_to(root_url)
      end
    end

    describe 'patch confirm' do
      it 'redirects to root url' do
        patch :confirm

        expect(response).to redirect_to(root_url)
      end
    end
  end

  describe 'when signed in before 2fa' do
    before do
      stub_analytics
      sign_in_before_2fa
    end

    describe 'GET show' do
      it 'redirects if no webauthn configured' do
        get :show

        expect(response).to redirect_to(user_two_factor_authentication_url)
      end
    end

    describe 'patch confirm' do
      let(:params) do
        {
          authenticator_data: authenticator_data,
          client_data_json: verification_client_data_json,
          signature: signature,
          credential_id: credential_id,
          ga_client_id: 'abc-cool-town-5',
        }
      end
      before do
        controller.user_session[:webauthn_challenge] = webauthn_challenge
        create(
          :webauthn_configuration,
          user: controller.current_user,
          credential_id: credential_id,
          credential_public_key: credential_public_key,
        )
      end

      it 'tracks a valid submission' do
        allow(WebauthnVerificationForm).to receive(:domain_name).and_return('localhost:3000')
        result = { context: 'authentication', errors: {}, multi_factor_auth_method: 'webauthn',
                   success: true }
        expect(@analytics).to receive(:track_mfa_submit_event).
          with(result, 'abc-cool-town-5')
        expect(@analytics).to receive(:track_event).
          with(Analytics::USER_MARKED_AUTHED, authentication_type: :valid_2fa)

        patch :confirm, params: params
      end

      it 'tracks an invalid submission' do
        result = { context: 'authentication', errors: {}, multi_factor_auth_method: 'webauthn',
                   success: false }
        expect(@analytics).to receive(:track_mfa_submit_event).
          with(result, 'abc-cool-town-5')

        patch :confirm, params: params
      end
    end
  end
end
