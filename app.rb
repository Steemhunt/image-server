require 'sinatra'
require 'sinatra/cors'
require 'aws-sdk-s3'
require 'dotenv'
require 'securerandom'

# Configs
Dotenv.load
Aws.config.update({
  region: 'us-west-2',
  credentials: Aws::Credentials.new("#{ENV['S3_ACCESS_KEY']}", "#{ENV['S3_SECRET_KEY']}")
})
set :allow_origin, Sinatra::Base.production? ? "https://steemhunt.com" : "http://localhost:3000 http://localhost:4567"
set :allow_methods, "GET,HEAD,POST"
set :allow_headers, "content-type,if-modified-since"
set :expose_headers, "location,link"

# Routes
get '/upload' do
  if Sinatra::Base.production?
    status 404
  else
    "
    <form action='/upload' method='post' enctype='multipart/form-data'>
      <input type='file' name='image' value='image-file'></input>
      <input type='submit'/>
    </form>
    "
  end
end

post '/upload' do
  content_type :json
  uploader = S3Uploader.new('huntimages')

  if res = uploader.upload(params[:image])
    res
  else
    status 500
  end
end

# Modules
class S3Uploader
  attr_accessor :bucket_name, :s3, :bucket, :space, :name, :path, :link

  def initialize(bucket_name)
    @bucket_name = bucket_name
    @s3 = Aws::S3::Resource.new
    @bucket = s3.bucket(bucket_name)
  end

  def upload(image)
    @name = image[:filename]
    @path = "images/#{SecureRandom.hex(16)}-#{name}"
    @path.prepend Sinatra::Base.production? ? "production/" : "development/"
    @link = "https://s3-us-west-2.amazonaws.com/#{bucket_name}/#{path}"
    @space = bucket.object(path)
    if space.upload_file(image[:tempfile], acl:'public-read')
      return render_json
    else
      return false
    end
  end

  private

  def render_json
    {
      data: {
        name: name, link: link
      },
      success: true,
      status: 200
    }.to_json
  end
end
