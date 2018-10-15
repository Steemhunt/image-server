require 'sinatra'
require 'sinatra/cors'
require 'aws-sdk-s3'
require 'dotenv'
require 'securerandom'
require 'time'

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
  attr_accessor :bucket_name, :s3, :bucket, :space, :name, :file, :path, :link, :temp_mp4, :is_gif

  def initialize(bucket_name)
    @bucket_name = bucket_name
    @s3 = Aws::S3::Resource.new
    @bucket = s3.bucket(bucket_name)
  end

  def upload(image)
    if image[:filename] =~ /.gif/
      converted = gif_to_mp4(image)
      @name, @file = converted[:filename], converted[:file]
    else
      @name, @file = image[:filename], image[:tempfile]
    end

    uid = "#{SecureRandom.hex(4)}-#{name}"
    path = "#{Sinatra::Base.production? ? "production" : "development"}/steemhunt/#{Time.now.strftime('%Y-%m-%d')}/#{uid}"

    @link = "https://s3-us-west-2.amazonaws.com/#{bucket_name}/#{path}"
    @space = bucket.object(path)
    if space.upload_file(file, acl:'public-read')
      File.unlink(file)
      return render_json
    else
      return false
    end
  end

  private

  def gif_to_mp4(image)
    temp_mp4 = './temp/temp.mp4'
    `osx/ffmpeg -i #{image[:tempfile].path} -movflags faststart -pix_fmt yuv420p -vf "scale=300:200" #{temp_mp4}`
    mp4_file = File.open(temp_mp4)

    return {
      file: mp4_file,
      filename: image[:filename].gsub('.gif', '.mp4')
    }
  end

  def destroy_temp
    File.unlink(temp_mp4)
  end

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
