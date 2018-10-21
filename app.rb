require 'sinatra'
require 'sinatra/cors'
require 'sinatra/reloader' if development?
require 'aws-sdk-s3'
require 'dotenv/load'
require 'securerandom'
require 'time'

Aws.config.update({
  region: 'us-west-2',
  credentials: Aws::Credentials.new(ENV['S3_ACCESS_KEY'], ENV['S3_SECRET_KEY'])
})
set :allow_origin, "https://steemhunt.com http://localhost:3000 http://localhost:4567"
set :allow_methods, "GET,HEAD,POST"
set :allow_headers, "content-type,if-modified-since"
set :expose_headers, "location,link"

configure { set :server, :puma }

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
      File.unlink(file)
      return {
        link: "https://s3-us-west-2.amazonaws.com/#{bucket_name}/#{path}"
      }
    else
      return false
    end
  end

end

class FileEncoder
  def to_mp4(target_file, options = {})
    default_options = {
      thumbnail: false
    }
    options = default_options.merge!(options)

    temp_mp4 = "./tmp/#{SecureRandom.hex(8)}.mp4"

    # ffmpeg options
    # - https://trac.ffmpeg.org/wiki/Encode/H.264
    # - https://trac.ffmpeg.org/wiki/Scaling
    if options[:thumbnail] # 92~3% minificaiton.
      `ffmpeg -y -i #{target_file.path} -movflags faststart -pix_fmt yuv420p -b:v 0 -crf 25 -vf "scale='min(160,iw)':-1"  #{temp_mp4}`
    else
      `ffmpeg -y -i #{target_file.path} -movflags faststart -pix_fmt yuv420p -b:v 0 -crf 25 -vf -vf "scale='min(880,iw)':-1  #{temp_mp4}`
    end

    File.open(temp_mp4)
  end
end

class App < Sinatra::Base
  # Routes
  get '/upload' do
    if Sinatra::Base.production?
      status 404
    else
      """
      <form action=\"/upload\" method=\"post\" enctype=\"multipart/form-data\">
        <input type=\"file\" name=\"image\" value=\"image-file\"></input>
        <input type=\"submit\"/>
      </form>
      """
    end
  end

  post '/upload' do
    content_type :json
    uploader = S3Uploader.new(ENV['S3_BUCKET'])
    encoder = FileEncoder.new
    image = params[:image]

    uid, filename, file = "#{Time.now.strftime('%Y-%m-%d')}/#{SecureRandom.hex(4)}-#{image[:filename]}", image[:filename], image[:tempfile]

    if filename =~ /\.gif$/
      # Upload thumbnail
      uploader.upload(uid.gsub('.gif', '-thumb.mp4'), encoder.to_mp4(file, { thumbnail: true }))

      # Change gif with mp4
      uid, filename, file = uid.gsub('.gif', '.mp4'), filename.gsub('.gif', '.mp4'), encoder.to_mp4(file)
    end

    if res = uploader.upload(uid, file)
      return {
        response: { name: filename, uid: uid, link: res[:link] },
        success: true,
        status: 200
      }.to_json
    else
      status 500
    end
  end
end
