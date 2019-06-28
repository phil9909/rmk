

require 'find'

# Encoding: utf-8
# @author Nikolay Yurin <yurinnick@outlook.com>

require 'yaml'

# DockerfileParser main class
class DockerfileParser
  @commands = %w(FROM MAINTAINER RUN CMD EXPOSE ENV ADD COPY ENTRYPOINT
                 VOLUME USER WORKDIR ONBUILD)

  # Parse Dockerfile from specified path
  # @return [Array<Hash>] parser Dockerfile
  def self.load_file(path)
    loads(File.read(path))
  end

  def self.loads(s)
    dockerfile_array = split_dockerfile(s)
    parse_commands(dockerfile_array).each_cons(2).map do |item|
      process_steps(dockerfile_array, item[0], item[1][:index])
    end
  end

  def self.split_dockerfile(str)
    str.gsub(/(\s\\\s)+/i, '').gsub("\n", ' ').squeeze(' ').split(' ')
  end

  def self.parse_commands(dockerfile_array)
    dockerfile_array.each_with_index.map do |cmd, index|
      { index: index, command: cmd } if @commands.include?(cmd)
    end.compact! << { index: dockerfile_array.length, command: 'EOF' }
  end

  def self.process_steps(dockerfile_array, step, next_cmd_index)
    { command: step[:command],
      params: split_params(
        step[:command],
        dockerfile_array[step[:index] + 1..next_cmd_index - 1]
      )
    }
  end

  def self.split_params(cmd, params)
    case cmd
    when 'FROM' then params.join('').split(':')
    when 'RUN' then params.join(' ').split(/\s(\&|\;)+\s/).map(&:strip)
    when 'ENV' then
      { name: params[0], value: params[1..-1].join(' ') }
    when 'COPY', 'ADD' then { src: params[0], dst: params[1] }
    else
      params = params.join(' ') if params.is_a?(Array)
      YAML.load(params.to_s)
    end
  end

  private_class_method :parse_commands
  private_class_method :process_steps
  private_class_method :split_params
  private_class_method :split_dockerfile
end


module Docker

  include Rmk::Tools

  def docker(options = {})
    docker_file = file("Dockerfile")
    docker_dir  = dir()
    result = []
    tar_file = File.join(build_dir,File.basename(docker_file)) + ".tgz"
    result << job(File.basename(tar_file),[docker_file]) do | hidden |
      DockerfileParser.load_file(docker_file).each do | cmd |
        case cmd[:command]
        when "COPY", "ADD"
          Find.find(File.join(docker_dir,cmd[:params][:src])) do |path|
            hidden[path] = true if File.file?(path)
          end
        end
      end
      p hidden
      out = system("docker build -f #{docker_file} #{docker_dir}")
      raise "Sha not found in output" unless out =~ /Successfully built ([0-9a-f]+)/
      FileUtils.mkdir_p(build_dir)
      system("docker save -o #{tar_file} #{$1}")
      tar_file
    end
    result
  end
  
end