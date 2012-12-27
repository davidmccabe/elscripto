require 'yaml'
require 'rbconfig'

module Elscripto # :nodoc:
  GLOBAL_CONF_PATH = File.join('/usr','local','etc')
  
  class AlreadyInitializedError < Exception # :nodoc:
    def initialize
      @message = ".elscripto found, project already initialized"
    end
  end
  
  class NoDefinitionsError < Exception # :nodoc:
    def initialize
      @message = "No definitions in your configuration file. What's the deal, guy?"
    end
  end
  
  class UnsupportedOSException < Exception # :nodoc:
    def initialize(os)
      @message = "Sorry, Elscripto does not currently support #{os}"
    end
  end
  
  # This is the application class used by the elscripto binary
  # Initialize it by passing a config file to it. 
  # Default file path is <current_dir>/.elscripto
  class App
    attr_accessor :commands, :platform, :enviroment, :generated_script
    CONFIG_FILE = File.join('.','.elscripto')
    
    def initialize opts_file, opts = {}
      @commands = []
      @generated_script = ""
      @platform = get_platform(Config::CONFIG['host_os'])
      first_run?
      @enviroment = opts.delete(:enviroment) || :production
      config_file = opts_file ? opts_file : CONFIG_FILE
      raise ArgumentError.new "Elscripto needs a config file spectacularrr" unless File.exists?(config_file)
      opts = YAML.load_file(config_file)
      raise Elscripto::NoDefinitionsError.new unless opts['commands'].class == Array
      opts['commands'].each do |cmd|
        case cmd.class.to_s
        when 'Hash'
          @commands << Command.new(cmd['name'], :command => cmd['command'])
        when 'String'
          @commands << Command.new(cmd)
        end
      end
    end
    
    def exec!
      raise Elscripto::NoDefinitionsError.new if self.commands.size == 0
      case self.platform
      # tell application "Terminal"
      # 	activate
      # 	delay 1
      # 	do script "clear && echo \"--STARTING SPORK SERVER--\" && cd Sites/tabbo/ && spork" in front window
      # 	tell application "System Events" to keystroke "t" using command down
      # 	do script "clear && echo \"--STARTING RAILS SERVER--\" && cd Sites/tabbo/ && rails c" in front window
      # 	tell application "System Events" to keystroke "t" using command down
      # 	do script "clear && echo \"--STARTING AUTOTEST--\" && cd Sites/tabbo/ && autotest" in front window
      # end tell
      when :osx
        @generated_script = %{tell application "Terminal"\n}
        @generated_script<< %{activate\n}
        @generated_script<< commands.map { |cmd| %{tell application "System Events" to keystroke "t" using command down\ndo script "clear && echo \\"-- Running #{cmd.name} Spectacularrr --\\" && #{cmd.system_call}" in front window} }.join("\n")
        @generated_script<< "\nend tell"
        if self.enviroment == :production
        begin
          tempfile = File.join('.','elscripto.tmp')
          File.open(tempfile,'w') { |f| f.write(@generated_script) }
          resp = `osascript #{tempfile}`
        ensure
          File.delete(tempfile)
        end
        else
          @generated_script
        end
      else
        raise Elscripto::UnsupportedOSException.new(self.platform)
      end
    end
    
    def first_run?
      case platform
      when :osx
        global_conf_file = File.join(GLOBAL_CONF_PATH,'elscripto.conf.yml')
        unless File.exists?(global_conf_file)
          File.open(global_conf_file,'w') do |f|
            f.write(File.read(File.join(File.dirname(__FILE__),'..','..','config','elscripto.conf.yml')))
          end
          puts "Wrote global configuration to #{global_conf_file}"
        end
      end
    end
    
    def self.init!
      if File.exists?(CONFIG_FILE)
        raise Elscripto::AlreadyInitializedError.new
      else
        File.open(CONFIG_FILE,'w') do |f|
          f.write File.read(File.join(File.dirname(__FILE__),'..','..','config','elscripto.init.yml')).gsub('{{GLOBAL_CONF_PATH}}',Elscripto::GLOBAL_CONF_PATH + '/elscripto.conf.yml')
        end
      end
    end
    
    # Determine the platform we're running on
    def get_platform(host_os)
      return :osx if host_os =~ /darwin/
      return :linux if host_os =~ /linux/
      return :windows if host_os =~ /mingw32|mswin32/
      return :unknown
    end
  end
end