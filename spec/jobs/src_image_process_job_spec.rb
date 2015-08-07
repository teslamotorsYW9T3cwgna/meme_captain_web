require 'rails_helper'

describe SrcImageProcessJob, type: :job do
  include ActiveJob::TestHelper

  context 'when the image needs to be loaded from a url' do
    let(:url) { 'http://www.example.com/image.jpg' }
    let(:src_image) { FactoryGirl.create(:src_image, image: nil, url: url) }

    before do
      image_data = File.read(Rails.root + 'spec/fixtures/files/ti_duck.jpg')
      stub_request(:get, url).to_return(body: image_data)
      stub_const('MemeCaptainWeb::Config::MIN_SOURCE_IMAGE_SIDE', 0)
    end

    it 'loads the image using the image url composer' do
      SrcImageProcessJob.perform_now(src_image.id)
      src_image.reload
      expect(src_image.magick_image_list.rows).to eq(399)
    end

    it 'creates the job in the src_image_process_url queue' do
      SrcImageProcessJob.perform_later(src_image.id)
      expect(enqueued_jobs.first[:queue]).to eq('src_image_process_url')
    end
  end

  it 'auto orients the image'

  it 'strips profiles and comments from the image'

  context 'when the image is too wide' do
    it "reduces the image's width" do
      stub_const('MemeCaptainWeb::Config::MIN_SOURCE_IMAGE_SIDE', 0)
      stub_const('MemeCaptainWeb::Config::MAX_SOURCE_IMAGE_SIDE', 80)
      src_image = FactoryGirl.create(
        :src_image, image: create_image(100, 50))
      SrcImageProcessJob.perform_now(src_image.id)
      src_image.reload

      expect(src_image.magick_image_list.columns).to eq(80)
      expect(src_image.magick_image_list.rows).to eq(40)
    end
  end

  context 'when the the image is too high' do
    it "reduces the image's height" do
      stub_const('MemeCaptainWeb::Config::MIN_SOURCE_IMAGE_SIDE', 0)
      stub_const('MemeCaptainWeb::Config::MAX_SOURCE_IMAGE_SIDE', 80)
      src_image = FactoryGirl.create(
        :src_image, image: create_image(100, 400))
      SrcImageProcessJob.perform_now(src_image.id)
      src_image.reload

      expect(src_image.magick_image_list.columns).to eq(20)
      expect(src_image.magick_image_list.rows).to eq(80)
    end
  end

  context 'when the image is too small' do
    it 'enlarges the image' do
      stub_const('MemeCaptainWeb::Config::ENLARGED_SOURCE_IMAGE_SIDE', 100)
      src_image = FactoryGirl.create(:src_image, image: create_image(20, 50))
      SrcImageProcessJob.perform_now(src_image.id)
      src_image.reload

      expect(src_image.magick_image_list.columns).to eq 40
      expect(src_image.magick_image_list.rows).to eq 100
    end
  end

  context 'when the image is too big to be processed' do
    before do
      stub_const('MemeCaptainWeb::Config::MAX_SRC_IMAGE_SIZE', 1)
    end

    it 'raises SrcImageTooBigError' do
      src_image = FactoryGirl.create(:src_image, image: create_image(100, 100))
      expect do
        SrcImageProcessJob.perform_now(src_image.id)
      end.to raise_error(MemeCaptainWeb::Error::SrcImageTooBigError,
                         "#{src_image.image.size} bytes")
    end
  end

  it 'watermarks the image' do
    stub_const('MemeCaptainWeb::Config::MIN_SOURCE_IMAGE_SIDE', 0)
    src_image = FactoryGirl.create(:src_image, image: create_image(100, 100))

    expect do
      SrcImageProcessJob.perform_now(src_image.id)
      src_image.reload
    end.to change { src_image.magick_image_list.excerpt(54, 95, 46, 5) }
  end

  it 'updates the image' do
    src_image = FactoryGirl.create(:src_image)
    expect do
      SrcImageProcessJob.perform_now(src_image.id)
      src_image.reload
    end.to change { src_image.image }
    expect(src_image.image).to_not be(nil)
  end

  it 'generates a thumbnail' do
    src_image = FactoryGirl.create(:src_image)
    SrcImageProcessJob.perform_now(src_image.id)
    expect(src_image.src_thumb).not_to be_nil
    expect(src_image.src_thumb.width).to eq(
      MemeCaptainWeb::Config::THUMB_SIDE)
    expect(src_image.src_thumb.height).to eq(
      MemeCaptainWeb::Config::THUMB_SIDE)
  end

  it 'marks the src image as finished' do
    src_image = FactoryGirl.create(:src_image)
    expect do
      SrcImageProcessJob.perform_now(src_image.id)
      src_image.reload
    end.to change { src_image.work_in_progress }.from(true).to(false)
  end

  it "enqueues a job to set the src image's name" do
    src_image = FactoryGirl.create(:src_image)
    expect(SrcImageNameJob).to receive(:perform_later).with(src_image.id)
    SrcImageProcessJob.perform_now(src_image.id)
  end

  it "sets the src image model's content type" do
    src_image = FactoryGirl.create(:src_image)
    expect do
      SrcImageProcessJob.perform_now(src_image.id)
      src_image.reload
    end.to change { src_image.content_type }.from(nil).to('image/jpeg')
  end

  it "sets the src image model's height" do
    src_image = FactoryGirl.create(:src_image)
    expect do
      SrcImageProcessJob.perform_now(src_image.id)
      src_image.reload
    end.to change { src_image.height }.from(nil).to(600)
  end

  it "sets the src image model's size" do
    src_image = FactoryGirl.create(:src_image)
    expect do
      SrcImageProcessJob.perform_now(src_image.id)
      src_image.reload
    end.to change { src_image.size }
  end

  it "sets the src image model's width" do
    src_image = FactoryGirl.create(:src_image)
    expect do
      SrcImageProcessJob.perform_now(src_image.id)
      src_image.reload
    end.to change { src_image.width }.from(nil).to(600)
  end

  it 'creates the job in the src_image_process queue' do
    src_image = FactoryGirl.create(:src_image)
    SrcImageProcessJob.perform_later(src_image.id)
    expect(enqueued_jobs.first[:queue]).to eq('src_image_process')
  end
end
