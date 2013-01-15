require 'spec_helper'

describe SrcImagesController do

  let(:user) { FactoryGirl.create(:user) }
  let(:user2) { FactoryGirl.create(:user, :email => 'user2@user2.com') }

  describe "GET 'new'" do
    it "returns http success" do
      get 'new'
      expect(response).to be_success
    end
  end

  describe "GET 'index'" do

    before(:each) do
      controller.stub(:current_user => user)
    end

    subject {
      get :index
    }

    it "returns http success" do
      subject

      expect(response).to be_success
    end

    it 'shows the images sorted by reverse updated time' do
      3.times { FactoryGirl.create(:src_image, :user => user) }

      subject

      src_images = assigns(:src_images)

      expect(
          src_images[0].updated_at >= src_images[1].updated_at &&
              src_images[1].updated_at >= src_images[2].updated_at).to be_true
    end

    it 'does not show deleted images' do
      FactoryGirl.create(:src_image, :user => user)
      FactoryGirl.create(:src_image, :user => user, :is_deleted => true)

      subject

      expect(assigns(:src_images).size).to eq 1
    end

  end

  describe "POST 'create'" do

    context 'with valid attributes' do

      it 'saves the new source image to the database' do
        expect {
          post :create, src_image: {
              :image => fixture_file_upload('/files/ti_duck.jpg', 'image/jpeg')}
        }.to change { SrcImage.count }.by(1)
      end

      it 'redirects to the index page' do
        post :create, src_image: {
            :image => fixture_file_upload('/files/ti_duck.jpg', 'image/jpeg')}

        expect(response).to redirect_to :action => :index
      end

      it 'informs the user of success with flash' do
        post :create, src_image: {
            :image => fixture_file_upload('/files/ti_duck.jpg', 'image/jpeg')}

        expect(flash[:notice]).to eq('Source image created.')
      end

    end

    context 'with invalid attributes' do

      it 'does not save the new source image in the database' do
        expect {
          post :create, src_image: {:image => nil}
        }.to_not change { SrcImage.count }
      end

      it 're-renders the new template' do
        post :create, src_image: {:image => nil}

        expect(response).to render_template('new')
      end

    end

  end

  describe "GET 'show'" do

    context 'when the id is found' do

      let(:src_image) {
        mock_model(SrcImage)
      }

      before :each do
        SrcImage.should_receive(:find_by_id_hash!).and_return(src_image)
      end

      it 'shows the source image' do
        get 'show', :id => 'abc'

        expect(response).to be_success
      end

      it 'has the right content type' do
        src_image.should_receive(:content_type).and_return('content type')

        get 'show', :id => 'abc'

        expect(response.content_type).to eq('content type')
      end

      it 'has the right content' do
        src_image.should_receive(:image).and_return('image')

        get 'show', :id => 'abc'

        expect(response.body).to eq('image')
      end

    end

    context 'when the id is not found' do

      it 'raises record not found' do
        expect {
          get 'show', :id => 'abc'
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

    end

  end

  describe "DELETE 'destroy'" do

    before(:each) do
      controller.stub(:current_user => user)
    end

    context 'when the id is found' do

      subject {
        post :create, src_image: {
            :image => fixture_file_upload('/files/ti_duck.jpg', 'image/jpeg')}
        delete :destroy, :id => assigns(:src_image).id_hash
      }

      it 'marks the record as deleted in the database' do
        subject

        expect {
          SrcImage.find_by_id_hash!(assigns(:src_image).id_hash).is_deleted?
        }.to be_true
      end

      it 'redirects to the index page' do
        subject
        expect(response).to redirect_to :action => :index
      end

    end

    context 'when the id is not found' do

      it 'raises record not found' do
        expect {
          delete :destroy, :id => 'abc'
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

    end

    context 'when the image is owned by another user' do

      it "doesn't allow it to be deleted" do
        src_image = FactoryGirl.create(:src_image, :user => user2)

        delete :destroy, :id => src_image.id_hash

        expect(response).to be_forbidden
      end

    end

  end

end