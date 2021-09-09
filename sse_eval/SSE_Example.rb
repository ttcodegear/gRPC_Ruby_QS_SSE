#!/usr/bin/env ruby

this_dir = File.expand_path(File.dirname(__FILE__))
stub_dir = File.join(this_dir, './')
$LOAD_PATH.unshift(stub_dir) unless $LOAD_PATH.include?(stub_dir)

require 'set'
require 'grpc'
require 'ServerSideExtension_services_pb'

class BindObject
  @args
  @result

  def initialize(args)
    @args = args
  end

  def bind
    binding
  end

  def result
    @result
  end
end

# Function Name | Function Type  | Argument     | TypeReturn Type
# ScriptEval    | Scalar, Tensor | Numeric      | Numeric
# ScriptEvalEx  | Scalar, Tensor | Dual(N or S) | Numeric
class ScriptEvalReplyEnumerator
  def initialize(header, requests)
    @header = header
    @requests = requests
  end

  def each_item
    puts 'script=' + @header.script
    # パラメータがあるか否かをチェック
    if !@header.params.empty?
      return enum_for(:each_item) unless block_given?
      @requests.each do |request|
        all_args = []
        request.rows.each do |row|
          script_args = []
          @header.params.zip(row.duals) { |param, dual|
            if param.dataType.to_s == 'NUMERIC' || param.dataType.to_s == 'DUAL'
              script_args.push(dual.numData)
            else
              script_args.push(dual.strData)
            end
          }
          puts 'args='
          p script_args
          all_args.push(script_args)
        end
        all_results = []
        all_args.each do |script_args|
          result = Float::NAN
          begin
            args = BindObject.new(script_args)
            eval(@header.script, args.bind)
            result = args.result
            if result.kind_of?(String)
              result = result.to_f
            end
          rescue Exception => ex
            puts ex
          end
          all_results.push(result)
        end
        response_rows = Qlik::Sse::BundledRows.new
        all_results.each do |result|
          dual = Qlik::Sse::Dual.new
          dual.numData = result
          row = Qlik::Sse::Row.new
          row.duals.push(dual)
          response_rows.rows.push(row)
        end
        yield response_rows
      end
    else
      return enum_for(:each_item) unless block_given?
      script_args = []
      result = Float::NAN
      begin
        args = BindObject.new(script_args)
        eval(@header.script, args.bind)
        result = args.result
        if result.kind_of?(String)
          result = result.to_f
        end
      rescue Exception => ex
        puts ex
      end
      dual = Qlik::Sse::Dual.new
      dual.numData = result
      row = Qlik::Sse::Row.new
      row.duals.push(dual)
      reply = Qlik::Sse::BundledRows.new
      reply.rows.push(row)
      yield reply
    end
  end
end

# Function Name   | Function Type | Argument     | TypeReturn Type
# ScriptAggrStr   | Aggregation   | String       | String
# ScriptAggrExStr | Aggregation   | Dual(N or S) | String
class ScriptAggrStrReplyEnumerator
  def initialize(header, requests)
    @header = header
    @requests = requests
  end

  def each_item
    puts 'script=' + @header.script
    # パラメータがあるか否かをチェック
    if !@header.params.empty?
      return enum_for(:each_item) unless block_given?
      @requests.each do |request|
        all_args = []
        request.rows.each do |row|
          script_args = []
          @header.params.zip(row.duals) { |param, dual|
            if param.dataType.to_s == 'STRING' || param.dataType.to_s == 'DUAL'
              script_args.push(dual.strData)
            else
              script_args.push(dual.numData)
            end
          }
          all_args.push(script_args)
        end
        puts 'args='
        p all_args
        result = ''
        begin
          args = BindObject.new(all_args)
          eval(@header.script, args.bind)
          result = args.result
          if !result.kind_of?(String)
            result = result.to_s
          end
        rescue Exception => ex
          puts ex
        end
        dual = Qlik::Sse::Dual.new
        dual.strData = result
        row = Qlik::Sse::Row.new
        row.duals.push(dual)
        reply = Qlik::Sse::BundledRows.new
        reply.rows.push(row)
        yield reply
      end
    else
      return enum_for(:each_item) unless block_given?
      script_args = []
      result = ''
      begin
        args = BindObject.new(script_args)
        eval(@header.script, args.bind)
        result = args.result
        if !result.kind_of?(String)
          result = result.to_s
        end
      rescue Exception => ex
        puts ex
      end
      dual = Qlik::Sse::Dual.new
      dual.strData = result
      row = Qlik::Sse::Row.new
      row.duals.push(dual)
      reply = Qlik::Sse::BundledRows.new
      reply.rows.push(row)
      yield reply
    end
  end
end

class ExtensionService < Qlik::Sse::Connector::Service
  # https://github.com/qlik-oss/server-side-extension/blob/master/docs/writing_a_plugin.md#script-evaluation
  def getFunctionName(header)
    # Read gRPC metadata
    func_type = header.functionType.to_s
    arg_types = header.params.map { |param| param.dataType.to_s }
    ret_type  = header.returnType.to_s
=begin
    if func_type == 'SCALAR' || func_type == 'TENSOR'
      puts 'func_type SCALAR TENSOR'
    elsif func_type == 'AGGREGATION'
      puts 'func_type AGGREGATION'
    end

    if arg_types.empty?
      puts 'arg_type Empty'
    elsif arg_types.all? { |t| t == 'NUMERIC' }
      puts 'arg_type NUMERIC'
    elsif arg_types.all? { |t| t == 'STRING' }
      puts 'arg_type STRING'
    elsif Set.new(arg_types).size >= 2 || arg_types.all? { |t| t == 'DUAL' }
      puts 'arg_type DUAL'
    end

    if ret_type == 'NUMERIC'
      puts 'ret_type NUMERIC'
    elsif ret_type == 'STRING'
      puts 'ret_type STRING'
    end
=end
    if func_type == 'SCALAR' || func_type == 'TENSOR'
      if arg_types.empty? or arg_types.all? { |t| t == 'NUMERIC' }
        if ret_type == 'NUMERIC'
          return 'ScriptEval'
        end
      end
    end

    if func_type == 'SCALAR' || func_type == 'TENSOR'
      if Set.new(arg_types).size >= 2 || arg_types.all? { |t| t == 'DUAL' }
        if ret_type == 'NUMERIC'
          return 'ScriptEvalEx'
        end
      end
    end

    if func_type == 'AGGREGATION'
      if arg_types.empty? || arg_types.all? { |t| t == 'STRING' }
        if ret_type == 'STRING'
          return 'ScriptAggrStr'
        end
      end
    end

    if func_type == 'AGGREGATION'
      if Set.new(arg_types).size >= 2 || arg_types.all? { |t| t == 'DUAL' }
        if ret_type == 'STRING'
          return 'ScriptAggrExStr'
        end
      end
    end

    return 'Unsupported Function Name'
  end

  def evaluate_script(requests, call)
    puts 'evaluate_script'
    call.merge_metadata_to_send({"qlik-cache" => "no-store"}) # Disable caching

    header = Qlik::Sse::ScriptRequestHeader.decode(call.metadata['qlik-scriptrequestheader-bin'])
    func_name = getFunctionName(header)
    if func_name == 'ScriptEval' || func_name == 'ScriptEvalEx'
      return ScriptEvalReplyEnumerator.new(header, requests).each_item
    end
    if func_name == 'ScriptAggrStr' || func_name == 'ScriptAggrExStr'
      return ScriptAggrStrReplyEnumerator.new(header, requests).each_item
    end

    raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::UNIMPLEMENTED)
  end

  def get_capabilities(requests, call)
    puts 'get_capabilities'
    capabilities = Qlik::Sse::Capabilities.new
    capabilities.allowScript = true
    capabilities.pluginIdentifier = 'Simple SSE Test'
    capabilities.pluginVersion = 'v0.0.1'
    return capabilities
  end
end

server = GRPC::RpcServer.new
server.add_http2_port('0.0.0.0:50053', :this_port_is_insecure)
server.handle(ExtensionService)
#server.run_till_terminated_or_interrupted(['SIGHUP', 'SIGINT', 'SIGQUIT'])
server.run_till_terminated_or_interrupted(%w[EXIT INT])
