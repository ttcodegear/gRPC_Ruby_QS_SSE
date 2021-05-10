#!/usr/bin/env ruby

this_dir = File.expand_path(File.dirname(__FILE__))
stub_dir = File.join(this_dir, './')
$LOAD_PATH.unshift(stub_dir) unless $LOAD_PATH.include?(stub_dir)

require 'grpc'
require 'ServerSideExtension_services_pb'

class SumOfColumnReplyEnumerator
  def initialize(requests, call)
    @requests = requests
    @call = call
  end

  def each_item
    puts 'SumOfColumn'
    return enum_for(:each_item) unless block_given?
    params = []
    @requests.each do |request|
      request.rows.each do |row|
        params.push(row.duals[0].numData) # row=[Col1]
      end
    end
    dual = Qlik::Sse::Dual.new
    dual.numData = params.sum
    row = Qlik::Sse::Row.new
    row.duals.push(dual)
    reply = Qlik::Sse::BundledRows.new
    reply.rows.push(row)
    yield reply
  end
end

class SumOfRowsReplyEnumerator
  def initialize(requests, call)
    @requests = requests
    @call = call
  end

  def each_item
    puts 'SumOfRows'
    return enum_for(:each_item) unless block_given?
    @requests.each do |request|
      response_rows = Qlik::Sse::BundledRows.new
      request.rows.each do |row|
        result = row.duals[0].numData + row.duals[1].numData # row=[Col1,Col2]
        dual = Qlik::Sse::Dual.new
        dual.numData = result
        row = Qlik::Sse::Row.new
        row.duals.push(dual)
        response_rows.rows.push(row)
      end
      yield response_rows
    end
  end
end

class ExtensionService < Qlik::Sse::Connector::Service
  def getFunctionId(call)
    # Read gRPC metadata
    header = call.metadata['qlik-functionrequestheader-bin']
    Qlik::Sse::FunctionRequestHeader.decode(header).functionId
  end

  def execute_function(requests, call)
    puts 'execute_function'
    call.merge_metadata_to_send({"qlik-cache" => "no-store"}) # Disable caching

    func_id = getFunctionId(call)
    if func_id == 0
      return SumOfColumnReplyEnumerator.new(requests, call).each_item
    elsif func_id == 1
      return SumOfRowsReplyEnumerator.new(requests, call).each_item
    else
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::UNIMPLEMENTED)
    end
  end

  def get_capabilities(requests, call)
    puts 'get_capabilities'
    capabilities = Qlik::Sse::Capabilities.new
    begin
      capabilities.allowScript = false
      capabilities.pluginIdentifier = 'Simple SSE Test'
      capabilities.pluginVersion = 'v0.0.1'

      # SumOfColumn
      func0 = Qlik::Sse::FunctionDefinition.new
      func0.functionId = 0                                      # 関数ID
      func0.name = 'SumOfColumn'                                # 関数名
      func0.functionType = Qlik::Sse::FunctionType::AGGREGATION # 関数タイプ=0=スカラー,1=集計,2=テンソル
      func0.returnType = Qlik::Sse::DataType::NUMERIC           # 関数戻り値=0=文字列,1=数値,2=Dual
      func0_p1 = Qlik::Sse::Parameter.new
      func0_p1.name = 'col1'                                    # パラメータ名
      func0_p1.dataType = Qlik::Sse::DataType::NUMERIC          # パラメータタイプ=0=文字列,1=数値,2=Dual
      func0.params.push(func0_p1)

      # SumOfRows
      func1 = Qlik::Sse::FunctionDefinition.new
      func1.functionId = 1                                      # 関数ID
      func1.name = 'SumOfRows'                                  # 関数名
      func1.functionType = Qlik::Sse::FunctionType::TENSOR      # 関数タイプ=0=スカラー,1=集計,2=テンソル
      func1.returnType = Qlik::Sse::DataType::NUMERIC           # 関数戻り値=0=文字列,1=数値,2=Dual
      func1_p1 = Qlik::Sse::Parameter.new
      func1_p1.name = 'col1'                                    # パラメータ名
      func1_p1.dataType = Qlik::Sse::DataType::NUMERIC          # パラメータタイプ=0=文字列,1=数値,2=Dual
      func1_p2 = Qlik::Sse::Parameter.new
      func1_p2.name = 'col2'                                    # パラメータ名
      func1_p2.dataType = Qlik::Sse::DataType::NUMERIC          # パラメータタイプ=0=文字列,1=数値,2=Dual
      func1.params.push(func1_p1)
      func1.params.push(func1_p2)

      capabilities.functions.push(func0)
      capabilities.functions.push(func1)
    rescue Exception => ex
      puts ex
      raise e
    end
    return capabilities
  end
end

server = GRPC::RpcServer.new
server.add_http2_port('0.0.0.0:50053', :this_port_is_insecure)
server.handle(ExtensionService)
#server.run_till_terminated_or_interrupted(['SIGHUP', 'SIGINT', 'SIGQUIT'])
server.run_till_terminated_or_interrupted(%w[EXIT INT])
