require 'rails_helper'

describe Users::PhonesController do
  include Features::MailerHelper

  describe '#phone' do
    let(:user) { create(:user, :signed_up, with: { phone: '+1 (202) 555-1234' }) }
    let(:second_user) { create(:user, :signed_up, with: { phone: '+1 (202) 555-5678' }) }
    let(:new_phone) { '202-555-4321' }

    context 'user changes phone' do
      before do
        stub_sign_in(user)

        stub_analytics
        allow(@analytics).to receive(:track_event)

        put :update, params: {
          user_phone_form: { phone: new_phone,
                             international_code: 'US',
                             otp_delivery_preference: 'sms' },
        }
      end

      it 'lets user know they need to confirm their new phone' do
        expect(
          MfaContext.new(user).phone_configurations.reload.first.phone,
        ).to_not eq '+1 202-555-4321'
        expect(@analytics).to have_received(:track_event).
          with(Analytics::PHONE_CHANGE_REQUESTED)
      end
    end

    context 'user enters an empty phone' do
      it 'does not delete the phone' do
        stub_sign_in(user)

        put :update, params: {
          user_phone_form: { phone: '',
                             international_code: 'US',
                             otp_delivery_preference: 'sms' },
        }

        expect(MfaContext.new(user).phone_configurations.reload.first).to be_present
        expect(response).to render_template(:edit)
      end
    end

    context "user changes phone to another user's phone" do
      before do
        stub_sign_in(user)

        stub_analytics
        allow(@analytics).to receive(:track_event)

        put :update, params: {
          user_phone_form: { phone: MfaContext.new(second_user).phone_configurations.first.phone,
                             international_code: 'US',
                             otp_delivery_preference: 'sms' },
        }
      end

      it 'processes successfully and informs user' do
        expect(MfaContext.new(user).phone_configurations.reload.first.phone).to_not eq(
          MfaContext.new(second_user).phone_configurations.first.phone,
        )
        expect(@analytics).to have_received(:track_event).
          with(Analytics::PHONE_CHANGE_REQUESTED)
      end
    end

    context 'user updates with invalid phone' do
      it 'does not change the user phone number' do
        invalid_phone = '123'
        user = build(:user, :with_phone, with: { phone: '123-123-1234' })
        stub_sign_in(user)

        put :update, params: {
          user_phone_form: { phone: invalid_phone,
                             international_code: 'US',
                             otp_delivery_preference: 'sms' },
        }

        expect(MfaContext.new(user).phone_configurations.first.phone).not_to eq invalid_phone
        expect(response).to render_template(:edit)
      end
    end

    context 'user submits the form without changing their phone' do
      it 'redirects to profile page without any messages' do
        stub_sign_in(user)

        put :update, params: {
          user_phone_form: { phone: MfaContext.new(user).phone_configurations.first.phone,
                             international_code: 'US',
                             otp_delivery_preference: 'sms' },
        }

        expect(response).to redirect_to account_url
        expect(flash.keys).to be_empty
      end
    end
  end

  describe '#delete' do
    before(:each) do
      stub_analytics
      allow(@analytics).to receive(:track_event)
    end

    context 'user has no phone' do
      let(:user) { create(:user) }

      let(:extra_analytics) do
        { configuration_id: nil,
          configuration_owner: nil,
          configuration_present: false,
          errors: {},
          mfa_method_counts: {},
          success: true }
      end

      it 'redirects without an error' do
        stub_sign_in(user)

        extra = extra_analytics

        delete :delete

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PHONE_DELETION_REQUESTED, extra)
        expect(response).to redirect_to(account_url)
      end
    end

    context 'user has only a phone' do
      let(:user) { create(:user, :with_phone, :with_webauthn) }

      let(:extra_analytics) do
        { configuration_id: user.phone_configurations.first.id,
          configuration_owner: user.uuid,
          configuration_present: true,
          errors: { user: ['must have 3 or more MFA configurations'] },
          mfa_method_counts: { webauthn: 1, phone: 1 },
          success: false }
      end

      it 'redirects without an error' do
        stub_sign_in(user)

        extra = extra_analytics

        delete :delete

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PHONE_DELETION_REQUESTED, extra)
        expect(response).to redirect_to(account_url)
      end

      it 'leaves the phone' do
        stub_sign_in(user)

        delete :delete

        user.phone_configurations.reload
        expect(user.phone_configurations.count).to eq 1
      end
    end

    context 'user has more than one mfa option' do
      let(:user) { create(:user, :signed_up, :with_piv_or_cac) }

      let(:extra_analytics) do
        { configuration_id: user.phone_configurations.first.id,
          configuration_owner: user.uuid,
          configuration_present: true,
          errors: {},
          mfa_method_counts: { piv_cac: 1 },
          success: true }
      end

      it 'redirects without an error' do
        stub_sign_in(user)

        extra = extra_analytics

        delete :delete

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PHONE_DELETION_REQUESTED, extra)
        expect(response).to redirect_to(account_url)
      end

      it 'removes the phone' do
        stub_sign_in(user)

        delete :delete

        user.phone_configurations.reload
        expect(user.phone_configurations).to be_empty
      end
    end
  end

  context 'user adds phone' do
    let(:user) { create(:user, :signed_up, with: { phone: '+1 (202) 555-1234' }) }
    let(:new_phone) { '202-555-4321' }
    before do
      stub_sign_in(user)

      stub_analytics
      allow(@analytics).to receive(:track_event)
    end

    it 'gives the user a form to enter a new phone number' do
      get :add
      expect(response).to render_template(:add)
    end

    it 'lets user know they need to confirm their new phone' do
      put :create, params: {
        user_phone_form: { phone: new_phone,
                           international_code: 'US',
                           otp_delivery_preference: 'sms' },
      }
      expect(flash[:notice]).to eq t('devise.registrations.phone_update_needs_confirmation')
      expect(
        MfaContext.new(user).phone_configurations.reload.first.phone,
      ).to_not eq '+1 202-555-4321'
      expect(response).to redirect_to(otp_send_path(otp_delivery_selection_form:
                                                      { otp_delivery_preference: 'sms',
                                                        otp_make_default_number: nil }))
      expect(subject.user_session[:context]).to eq 'confirmation'
    end
  end
end
