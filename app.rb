require 'bundler'
require 'fileutils'
Bundler.require

enable :logging

get '/' do
  @files = Dir["uploads/*"].map {|f| f.split('/').last}
  slim :index
end

get '/download/:filename' do |filename|
  send_file "./uploads/#{filename}", filename: filename, type: 'Application/octet-stream'
end

post '/upload' do
  params['files'].each {|file| FileUtils.copy file[:tempfile], "uploads/#{file[:filename]}"}
  audio_conversion.run
  redirect '/'
end

post '/generate' do
  %w(msg predecroche repondeur).each do |part|
    filename = "uploads/#{params['filename']}-#{part}.wav"
    %x(say -v Audrey -o "#{filename}" --data-format=LEF32@8000 #{params[part]})
    # audio_conversion.add_background_music filename if params['add_background']
    audio_conversion.convert_to_a_law filename
  end
  redirect '/'
end

post '/clear' do
  Dir["uploads/*"].each {|f| File.delete f}
  redirect '/'
end

def audio_conversion
  @audio_conversion ||= AudioConversion.new logger
end

class AudioConversion
  
  attr_accessor :logger
  
  def initialize logger
    @logger = logger
  end
  
  def run
    convert
  end
  
  def convert
    logger.info "Start conversion"
    Dir["uploads/*"].each do |file|
      logger.info "File : #{file}"
      %x(mplayer -vo null -vc null -af resample=8000 -ao pcm:waveheader #{file})
      dest_file = file.gsub('.wma', '.wav')
      next if File.exists? dest_file
      %x(mv audiodump.wav #{dest_file})
      add_background_music dest_file unless no_background? dest_file
      convert_to_a_law dest_file
      %x(rm "#{file}")
    end
  end
  
  def add_background_music filename
    logger.info "Get file length"
    length = %x(sox "#{filename}" -n stat 2>&1 | grep Length | ruby -e "puts ARGF.gets.split.last")
    length = length.to_f.ceil
    logger.info "Mix with background"
    %x(sox -m -v 0.2 "#{File.dirname(__FILE__)}/loop-background.wav" -v 1 "#{filename}" "temp.wav")
    logger.info "Trim mix"
    %x(sox "temp.wav" "#{filename}" trim 0 #{length})
    %x(rm "temp.wav")
  end
  
  def convert_to_a_law filename
    logger.info "Convert to A-law"
    %x(sox "#{filename}" -e a-law -c 1 -r 8000 "temp.wav")
    %x(mv "temp.wav" "#{filename}" ; rm "temp.wav")
  end
  
  def no_background? file
    file['-msg'] || file['message-'] || file['msg-'] || file['sansmusique']
  end
  
end
