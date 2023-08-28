#!/usr/bin/env ruby

require 'optparse'
require 'pathname'
require 'fileutils'

def main
  options = {
    docker_image: File.join(Dir.pwd, 'home'),
    search_term: Dir.home,
    bust_cache: false,
    pull_image: false,
    runtime: 'docker',
  }
  args =
    OptionParser
      .new do |opts|
        opts.banner = "Usage:\t#{$0} [OPTIONS] <IMAGE> <SEARCH_TERM>"

        opts.on(
          '-b',
          '--bust-cache',
          'Overwrite any existing cached files',
        ) { |p| options[:bust_cache] = p }

        opts.on('-p', '--pull-image', 'Pull the image from the registry') do |p|
          options[:pull_image] = p
        end

        opts.on(
          '-r',
          '--runtime RUNTIME',
          'Select which container runtime to use',
        ) { |p| options[:runtime] = p }

        opts.on('--list-runtimes', 'Gets a list of supported runtimes') do
          puts 'Supported runtimes:'
          puts 'docker, podman'
          exit 0
        end

        opts.on('-h', '--help', 'Prints this help') do
          puts opts
          exit 0
        end
      end
      .parse!
  options[:search_term] = args.pop
  options[:docker_image] = args.pop

  docker_image_path = Pathname.new(options[:docker_image])
  tmp_dir = make_tmp_dir('/tmp/io.orleans.container-image-deep-search')
  docker_tar = File.join(tmp_dir, "#{docker_image_path.basename}.tar")
  untar_dir = File.join(tmp_dir, docker_image_path.basename)

  pull_image(options[:runtime], options[:docker_image]) if options[:pull_image]
  save_tar(
    options[:runtime],
    options[:docker_image],
    docker_tar,
    options[:bust_cache],
  )
  untar(untar_dir, docker_tar, options[:bust_cache])
  search(untar_dir, options[:search_term])

  exit 0
end

def make_tmp_dir(tmp_dir)
  Dir.mkdir(tmp_dir) if !File.exists?(tmp_dir)
  tmp_dir
end

def pull_image(runtime, image)
  STDERR.puts "Pulling #{image}"
  `#{runtime} pull #{image}`
end

def save_tar(runtime, docker_image, docker_tar, bust_cache)
  if !File.exists? docker_tar or bust_cache
    STDERR.puts "Saving image #{docker_image} to tar"
    `#{runtime} save --output "#{docker_tar}" "#{docker_image}"`
  else
    puts 'Found image tar'
  end
end

def untar(untar_dir, docker_tar, bust_cache)
  if File.directory?(untar_dir) and !bust_cache
    STDERR.puts "Found untarred #{docker_tar}"
  else
    STDERR.puts "Deeply untarring #{docker_tar}"

    Dir.mkdir(untar_dir)
    `tar -xzf "#{docker_tar}" --directory "#{untar_dir}"`

    for tar in Dir.glob("#{untar_dir}/**/*.tar")
      STDERR.puts "Untarring layer #{File.basename File.dirname tar}"
      `tar -xzf "#{tar}" --directory "#{File.dirname tar}"`
      File.delete tar
    end
  end
end

def search(untar_dir, search_term)
  STDERR.puts "Searching for #{search_term}"
  puts `grep --recursive --color=always "#{search_term}" "#{untar_dir}"`
end

main
