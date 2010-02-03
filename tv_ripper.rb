class HandBrake
  
  attr_accessor :input_path, :output_path
  attr_reader :presets
  
  def initialize(input_path, output_path)
    @input_path = input_path
    @output_path = output_path
    @presets = {}
    
    @presets[:apple_tv] = '--preset="AppleTV"'
    @presets[:iphone] = '-e x264 -q 0.55 -B 128 -R 48 -E faac -f mp4 -I -w 480 -m -x level=30:cabac=0:ref=1:analyse=all:me=umh:subme=6:no-fast-pskip=1:trellis=1'
    @presets[:xbox_360] = '-e x264 -q 0.667 -B 160 -R 48 -E faac -f mp4 -p -x level=40:ref=2:mixed-refs=1:bframes=3:bime=1:weightb=1:brdo=1:direct=auto:b-pyramid=1:me=umh:subq=6:analyse=all:no-fast-pskip=1:deblock=-2,-1:no-dct-decimate=1'
  end
  
  def titles
    unless @titles
      puts "\nScanning for titles on #{@input_path}. This may take a while..."
    
      result = `./HandBrakeCLI -i #{input_path} -t 0 2>&1`
    
      title_numbers = result.scan(/\+ title (\d+)/)
      title_durations = result.scan(/\+ duration: (\d\d:\d\d:\d\d)/)
      title_fps = result.scan(/\+ size: \d+x\d+, aspect: \d+\.\d+, (\d+\.\d+) fps/)

      @titles = []

      title_numbers.each_index do |i|
        @titles << {:number => title_numbers[i], :duration => duration_to_minutes(title_durations[i]), :fps => title_fps[i].to_s}
      end
    end

    return @titles
  end
  
  def transcode_title(file_name, title_number, preset, deinterlace=false)
    puts "Ripping #{@output_path}/#{file_name}_#{title_number}.m4v"
    
    if deinterlace
      d = "-d slower"
      puts "Interlacing detected."
    else
      d = ""
      puts "Progressive detected."
    end
    
    `./HandBrakeCLI -i #{@input_path} -o #{@output_path}/#{file_name}_T#{title_number}_#{get_duration(title_number)}m_#{preset.to_s}.m4v --title #{title_number} #{d} #{presets[preset]}`
  end
  
  def transcode_titles_by_time(min, max, file_name, preset)
    titles_by_time(min, max).each do |title|
      transcode_title(file_name, title[:number], preset, title[:fps] == "29.970")
    end
  end
  
  private
  
  def duration_to_minutes(duration)
    if duration.to_s =~ /(\d\d):(\d\d):(\d\d)/
      return ($1.to_i * 60) + $2.to_i
    else
      return 0
    end
  end
  
  def get_duration(title_number)
    titles.each do |title|
      return title[:duration] if title[:number] == title_number
    end
  end
  
  def titles_by_time(min, max)
    titles.select {|title| title[:duration] < max && title[:duration] > min}
  end

  def self.discover_dvd()
    Dir.open("/Volumes") do |volumes|
      volumes.each do |volume|
        return "/Volumes/#{volume}" if File.exists?("/Volumes/#{volume}/VIDEO_TS")
      end
    end
    
    return nil
  end
  
  def self.discover_dvd_name()
    dvd_path = discover_dvd()
    
    if dvd_path
      return dvd_path.sub(/\/Volumes\//, "")
    else
      return nil
    end
  end
end

def ask(question, default)
  
  if default.nil?
    puts question
  else
    puts "#{question} (#{default})"
  end
  
  result = gets.chomp!
  
  if result.nil? || result.empty?
    return default
  else
    return result
  end
end

input_path = ask("Where is the DVD?", HandBrake.discover_dvd)
output_path = ask("Where do you want to save the files?", "~/Desktop/rip")
file_name = ask("What do you want to name the file?", HandBrake.discover_dvd_name)

hb = HandBrake.new(input_path, output_path)

hb.transcode_titles_by_time(20, 120, "#{file_name}", :xbox_360)
hb.transcode_titles_by_time(20, 120, "#{file_name}", :iphone)


