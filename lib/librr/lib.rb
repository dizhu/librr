def redirect_std
  stdin = $stdin.dup
  stdout = $stdout.dup
  stderr = $stderr.dup

  ri, wi = IO::pipe
  ro, wo = IO::pipe
  re, we = IO::pipe

  $stdin.reopen ri
  $stdout.reopen wo
  $stderr.reopen we

  yield

  $stdin.reopen stdin
  $stdout.reopen stdout
  $stderr.reopen stderr
  [wi, ro, re]
end

def redirect_std_to_file(filename)
  f = File.open(filename, 'a+')
  f.sync = true

  $stdout.reopen f
  $stderr.reopen f

  yield
end


def fix_encoding text
  # solution copy from:
  # http://stackoverflow.com/questions/11375342/stringencode-not-fixing-invalid-byte-sequence-in-utf-8-error
  text
    .encode('UTF-16', undef: :replace, invalid: :replace, replace: "")
    .encode('UTF-8')
end

def kill_process_by_file file
  begin
    pid = File.read(file).to_i
    Process.kill 'TERM', pid if pid > 0
    File.delete file
  rescue
  end
end

require 'rbconfig'

def os
  @os ||= (
    host_os = RbConfig::CONFIG['host_os']
    case host_os
    when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
      :windows
    when /darwin|mac os/
      :macosx
    when /linux/
      :linux
    when /solaris|bsd/
      :unix
    else
      raise Error::WebDriverError, "unknown os: #{host_os.inspect}"
    end
    )
end
