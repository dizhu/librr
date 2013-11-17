require 'eventmachine'
require 'evma_httpserver'
require 'rb-fsevent'

require 'librr/settings'
require 'json'
require 'rack'
require 'set'

EventMachine.kqueue = true if EventMachine.kqueue?

class Indexer
  FILES = {}

  def index_directory(dir)
    Dir.glob(File.join(dir, "**/*")).each do |file|
      next unless File.file?(file)
      self.index_file(file)
    end
  end

  def index_file(file)
    puts "index file: #{file}"
    lines = File.readlines(file) rescue []
    FILES[file] = lines
  end

  def search(str)
    result = []
    FILES.each do |file, lines|
      lines.each_with_index do |line, index|
        next unless line.index(str)
        result << [file, index, line]
      end
    end
    return result
  end
end

$indexer = Indexer.new

module DirMonitor
  DIRS = Set.new ['/Users/halida/data/workspace/librr']
  OBJS = {}
  @@pipe = nil

  OPTS = ["--file-events"]

  def self.add_directory(dir)
    puts "add directory: #{dir}"
    $indexer.index_directory(dir)
    DIRS.add(dir)
    self.start
  end

  def self.remove_directory(dir)
    puts "remove directory: #{dir}"
    DIRS.delete(dir)
    self.start
  end

  def post_init
    # count up to 5
  end

  def receive_data data
    changes = data.strip.split(':').map(&:strip).reject{|s| s == ''}
    changes.each do |file|
      $indexer.index_file(file)
    end
  end

  def unbind
    puts "stopped monitor process.."
  end

  def self.init
    DIRS.each do |dir|
      $indexer.index_directory(dir)
    end
    self.start
  end

  def self.start
    @pipe.close_connection if @pipe
    cmd = [FSEvent.watcher_path] + OPTS + DIRS.to_a
    puts "start monitor process: #{cmd}"
    @pipe = EM.popen(cmd, DirMonitor)
  end
end

module DirWatcher
  def file_modified
    puts "#{path} modified"
  end

  def file_moved
    puts "#{path} moved"
  end

  def file_deleted
    puts "#{path} deleted"
  end

  def unbind
    puts "#{path} monitoring ceased"
  end
end


$monitor = DirMonitor

class Librr::CmdServer < EM::Connection
  include EM::HttpServer

  def post_init
    super
    no_environment_strings
  end

  def process_http_request
    puts  @http_request_uri
    response = EM::DelegatedHttpResponse.new(self)
    response.status = 200
    response.content_type 'application/json'
    params = Rack::Utils.parse_nested_query(@http_post_content)
    response.content = JSON.dump(self.handle_cmd(params))
    response.send_response
  end

  def handle_cmd(params)
    case params['cmd']
    when 'start'
    when 'stop'
    when 'add'
      EM.next_tick{
        $monitor.add_directory(params['dir'])
      }
    when 'remove'
      EM.next_tick{
        $monitor.remove_directory(params['dir'])
      }
    when 'list'
      self.dirs
    when 'search'
      $indexer.search(params['text'])
    end
  end
end

class Librr::Runner
  def run
    EventMachine.run {
      EventMachine.start_server "127.0.0.1", Settings::RUNNER_PORT, Librr::CmdServer
      $monitor.init
    }
  end
end
