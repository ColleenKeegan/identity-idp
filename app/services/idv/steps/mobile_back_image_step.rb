module Idv
  module Steps
    class MobileBackImageStep < DocAuthBaseStep
      def call
        good, data = post_back_image
        return failure(data) unless good

        failure_data, data = verify_back_image(reset_step: :mobile_front_image)
        return failure_data if failure_data

        extract_pii_from_doc(data)
      end

      private

      def form_submit
        Idv::ImageUploadForm.new.submit(permit(:image))
      end
    end
  end
end
