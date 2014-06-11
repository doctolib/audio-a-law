require 'bundler'
require 'fileutils'
Bundler.require

get '/' do
  @files = Dir["uploads/*"].map {|f| f.split('/').last}
  slim :index
end

get '/download/:filename' do |filename|
  send_file "./uploads/#{filename}", filename: filename, type: 'Application/octet-stream'
end

post '/upload' do
  params['files'].each {|file| FileUtils.copy file[:tempfile], "uploads/#{file[:filename]}"}
  AudioConversion.run logger
  redirect '/'
end

post '/clear' do
  Dir["uploads/*"].each {|f| File.delete f}
  redirect '/'
end

class AudioConversion
  
  def self.logger
    @@logger
  end
  
  def self.run logger
    @@logger = logger
    convert
  end
  
  def self.convert
    logger.info "Start conversion"
    Dir["uploads/*"].each do |file|
      logger.info "File : #{file}"
      %x(mplayer -vo null -vc null -af resample=8000 -ao pcm:waveheader #{file})
      new_file = file.gsub('.wma', '.wav')
      next if File.exists? new_file
      %x(mv audiodump.wav #{file})
      unless ARGV[1] == 'no_background' || file['-msg'] || file['message-'] || file['msg-']
        logger.info "Get file length"
        length = %x(sox "#{file}" -n stat 2>&1 | grep Length | ruby -e "puts ARGF.gets.split.last")
        length = length.to_f.ceil
        logger.info "Mix with background"
        %x(sox -m -v 0.2 "#{File.dirname(__FILE__)}/loop-background.wav" -v 1 "#{file}" "#{new_file}")
        logger.info "Trim mix"
        %x(sox "#{new_file}" "#{new_file.gsub('.wav', '_short.wav')}" trim 0 #{length})
        logger.info "Convert to A-law"
        %x(sox "#{new_file.gsub('.wav', '_short.wav')}" -e a-law -c 1 -r 8000 "#{new_file}")
        %x(rm "#{new_file.gsub('.wav', '_short.wav')}")
      else
        logger.info "Convert to A-law"
        %x(sox "#{file}" -e a-law -c 1 -r 8000 "#{new_file}")
      end
      %x(rm #{file})
    end
  end
  
end
