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
  encoder = FileEncoder.new
  image = params[:image]

  uid, filename, file = "#{Time.now.strftime('%Y-%m-%d')}/#{SecureRandom.hex(4)}-#{image[:filename]}", image[:filename], image[:tempfile]

  if filename =~ /\.gif$/
    uploader.upload(uid.gsub('.gif', '-240x240.mp4'), encoder.to_mp4(file, { minify: true })[:file]) # upload minified
    uid, filename, file = uid.gsub('.gif', '.mp4'), filename.gsub('.gif', '.mp4'), encoder.to_mp4(file)[:file]
  end

  if res = uploader.upload(uid, file)
    File.unlink(file) # unlink image[:tempfile] or transformed temp.mp4 or minified temp.mp4
    return {
      response: {
        name: filename, uid: uid, link: res[:link]
      },
      success: true,
      status: 200
    }.to_json
  else
    status 500
  end
end

# Modules
class S3Uploader
  attr_accessor :s3, :bucket, :bucket_name

  def initialize(bucket_name)
    @bucket_name = bucket_name
    @s3 = Aws::S3::Resource.new
    @bucket = s3.bucket(bucket_name)
  end

  def upload(uid, file)
    path = "#{Sinatra::Base.production? ? "production" : "development"}/steemhunt/#{uid}"

    if bucket.object(path).upload_file(file, acl: 'public-read')
      return {
        link: "https://s3-us-west-2.amazonaws.com/#{bucket_name}/#{path}"
      }
    else
      return false
    end
  end

end

class FileEncoder
  FFMPEG_PATH = "#{Sinatra::Base.production? ? 'ubuntu' : 'osx'}/ffmpeg"

  def to_mp4(target_file, options = {})
    default_options = {
      minify: false
    }
    options = default_options.merge!(options)

    temp_mp4 = './temp/temp.mp4'

    if options[:minify] # 92~3% minificaiton.
      `#{FFMPEG_PATH} -y -i #{target_file.path} -movflags faststart -pix_fmt yuv420p -vf "scale=trunc(iw/4)*2:trunc(ih/4)*2" #{temp_mp4}`
    else
      `#{FFMPEG_PATH} -y -i #{target_file.path} -movflags faststart -pix_fmt yuv420p -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" #{temp_mp4}`
    end

    mp4_file = File.open(temp_mp4)

    return {
      file: mp4_file
    }
  end
end
