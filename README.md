# gRPC_Ruby_QS_SSE
$>ruby --version

ruby 2.6.5p114



$>gem install grpc

$>gem install grpc-tools

$>gem list

...

google-protobuf (3.16.0)

googleapis-common-protos-types (1.0.6)

grpc (1.37.1)

grpc-tools (1.37.1)

...





$>mkdir simple

$>cd simple

$>grpc_tools_ruby_protoc -I ./ --ruby_out=./ --grpc_out=./ helloworld.proto

$>ls *.rb

helloworld_pb.rb

helloworld_services_pb.rb

$>emacs greeter_server.rb

-------------

...

require 'grpc'

require 'helloworld_services_pb'



class GreeterServer < Helloworld::Greeter::Service

  def say_hello(request, call)

    puts "Received request: #{request}"

    reply = "こんにちは #{request.name}!"

    Helloworld::HelloReply.new(message: reply)

  end

end



server = GRPC::RpcServer.new

server.add_http2_port('0.0.0.0:50051', :this_port_is_insecure)

server.handle(GreeterServer)

#server.run_till_terminated_or_interrupted(['SIGHUP', 'SIGINT', 'SIGQUIT'])

server.run_till_terminated_or_interrupted(%w[EXIT INT])

-------------

$>emacs greeter_client.rb

-------------

...

require 'grpc'

require 'helloworld_services_pb'



stub = Helloworld::Greeter::Stub.new('localhost:50051', :this_channel_is_insecure)

begin

  response = stub.say_hello(Helloworld::HelloRequest.new(name: '山田太郎'))

  puts "Greeter client received: #{response.message}"

rescue Exception => ex

  puts ex

end

-------------

$>ruby greeter_server.rb

$>ruby greeter_client.rb





$>mkdir simple_ssl

$>cd simple_ssl

$>ruby greeter_ssl_server.rb

-------------

...

files = ['./server.crt', './server.key', './server.crt']

certs = files.map { |f| File.open(f).read }

server_creds = GRPC::Core::ServerCredentials.new(

        nil, [{private_key: certs[1], cert_chain: certs[2]}], false)



server = GRPC::RpcServer.new

server.add_http2_port('0.0.0.0:50051', server_creds)

...

-------------

$>ruby greeter_ssl_client.rb

-------------

...

channel_creds = GRPC::Core::ChannelCredentials.new(File.read("./server.crt"))

stub = Helloworld::Greeter::Stub.new('localhost:50051', channel_creds)

...

-------------

$>ruby greeter_ssl_server.rb

$>ruby greeter_ssl_client.rb





$>mkdir stream

$>cd stream

$>grpc_tools_ruby_protoc -I ./ --ruby_out=./ --grpc_out=./ hellostreamingworld.proto

$>ruby greeter_stream_server.rb

-------------

...

class MultiGreeterServer < Hellostreamingworld::MultiGreeter::Service

  def say_hello(requests, call)

    ReplyEnumerator.new(requests, call).each_item

  end

end



class ReplyEnumerator

  def initialize(requests, call)

    @requests = requests

    @call = call

  end



  def each_item

    return enum_for(:each_item) unless block_given?

    @requests.each do |request|

      puts "Received request: #{request}"

      request.num_greetings.to_i.times do |i|

        reply = "こんにちは #{request.name}! #{i}"

        yield Hellostreamingworld::HelloReply.new(message: reply)

      end

    end

  end

end

...

-------------

$>ruby greeter_stream_client.rb

-------------

...

class ReuestEnumerator

  def initialize()

    @requests = [

      Hellostreamingworld::HelloRequest.new(name: '山田太郎', num_greetings: "5"),

      Hellostreamingworld::HelloRequest.new(name: 'FooBar', num_greetings: "5")

    ]

  end



  def each_item

    return enum_for(:each_item) unless block_given?

    @requests.each do |request|

      yield request

    end

  end

end

...

  responses = stub.say_hello(ReuestEnumerator.new().each_item)

  responses.each do |response|

    puts "Greeter client received: #{response.message}"

  end

  ...

-------------

$>ruby greeter_stream_server.rb

$>ruby greeter_stream_client.rb





$>mkdir sse

$>cd sse

$>grpc_tools_ruby_protoc -I ./ --ruby_out=./ --grpc_out=./ ServerSideExtension.proto

$>ruby SSE_Example.rb



C:\Users\[user]\Documents\Qlik\Sense\Settings.ini

------

[Settings 7]

SSEPlugin=Column,localhost:50053



------

[for SSL]

------

...

files = ['./root_cert.pem', './sse_server_key.pem', './sse_server_cert.pem']

certs = files.map { |f| File.open(f).read }

server_creds = GRPC::Core::ServerCredentials.new(

        certs[0], [{private_key: certs[1], cert_chain: certs[2]}], false)

...

server.add_http2_port('0.0.0.0:50053', server_creds)

...

------

C:\Users\[user]\Documents\Qlik\Sense\Settings.ini

------

[Settings 7]

SSEPlugin=Column,localhost:50053,C:\...\sse_Column_generated_certs\sse_Column_client_certs_used_by_qlik



------

