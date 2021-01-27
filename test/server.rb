require "webrick/https"
require "net/empty_port"

class TestServer
  def initialize
    @server = silence_stderr do
      WEBrick::HTTPServer.new(
        ServerName: "localhost",
        Port: port,
        SSLEnable: true,
        SSLCertName: [%w[CN localhost]],
        Logger: WEBrick::Log.new(File.open(File::NULL, "w")),
        AccessLog: []
      )
    end

    @server.mount_proc "/" do |req, res|
      @request_body = req.body
      res.status = 200
      res.body = "RESPONSE"
    end
  end

  def silence_stderr
    $stderr = File.new("/dev/null", "w")
    ret = yield
    $stdout = STDERR
    ret
  end

  def port
    @port ||= Net::EmptyPort.empty_port
  end

  def request_body
    return {} if @request_body.empty?

    JSON.parse(@request_body)
  end

  def request_records
    return [] if request_body.empty?

    request_body["Records"]
  end

  def start
    trap "INT" do @server.shutdown end
    Thread.new do
      @server.start
    end
  end
end
