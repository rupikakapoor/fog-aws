require 'fog/core'
require 'fog/xml'
require 'fog/json'

require File.expand_path('../aws/version', __FILE__)

module Fog
  module CDN
    autoload :AWS,  File.expand_path('../aws/cdn', __FILE__)
  end

  module Compute
    autoload :AWS, File.expand_path('../aws/compute', __FILE__)
  end

  module DNS
    autoload :AWS, File.expand_path('../aws/dns', __FILE__)
  end

  module Storage
    autoload :AWS, File.expand_path('../aws/storage', __FILE__)
  end

  module AWS
    extend Fog::Provider

    autoload :CredentialFetcher, File.expand_path('../aws/credential_fetcher', __FILE__)
    autoload :Errors, File.expand_path('../aws/errors', __FILE__)
    autoload :Mock, File.expand_path('../aws/mock', __FILE__)
    autoload :ServiceMapper, File.expand_path('../aws/service_mapper', __FILE__)
    autoload :SignatureV4, File.expand_path('../aws/signaturev4', __FILE__)

    # Services
    autoload :AutoScaling,      File.expand_path('../aws/auto_scaling', __FILE__)
    autoload :CloudFormation,   File.expand_path('../aws/cloud_formation', __FILE__)
    autoload :CloudWatch,       File.expand_path('../aws/cloud_watch', __FILE__)
    autoload :DataPipeline,     File.expand_path('../aws/data_pipeline', __FILE__)
    autoload :DynamoDB,         File.expand_path('../aws/dynamodb', __FILE__)
    autoload :ECS,              File.expand_path('../aws/ecs', __FILE__)
    autoload :EFS,              File.expand_path('../aws/efs', __FILE__)
    autoload :ELB,              File.expand_path('../aws/elb', __FILE__)
    autoload :ELBV2,            File.expand_path('../aws/elbv2', __FILE__)
    autoload :EMR,              File.expand_path('../aws/emr', __FILE__)
    autoload :ElasticBeanstalk, File.expand_path('../aws/beanstalk', __FILE__)
    autoload :Elasticache,      File.expand_path('../aws/elasticache', __FILE__)
    autoload :Federation,       File.expand_path('../aws/federation', __FILE__)
    autoload :Glacier,          File.expand_path('../aws/glacier', __FILE__)
    autoload :IAM,              File.expand_path('../aws/iam', __FILE__)
    autoload :Kinesis,          File.expand_path('../aws/kinesis', __FILE__)
    autoload :KMS,              File.expand_path('../aws/kms', __FILE__)
    autoload :Lambda,           File.expand_path('../aws/lambda', __FILE__)
    autoload :RDS,              File.expand_path('../aws/rds', __FILE__)
    autoload :Redshift,         File.expand_path('../aws/redshift', __FILE__)
    autoload :SES,              File.expand_path('../aws/ses', __FILE__)
    autoload :SNS,              File.expand_path('../aws/sns', __FILE__)
    autoload :SQS,              File.expand_path('../aws/sqs', __FILE__)
    autoload :STS,              File.expand_path('../aws/sts', __FILE__)
    autoload :Support,          File.expand_path('../aws/support', __FILE__)
    autoload :SimpleDB,         File.expand_path('../aws/simpledb', __FILE__)

    service(:auto_scaling,    'AutoScaling')
    service(:beanstalk,       'ElasticBeanstalk')
    service(:cdn,             'CDN')
    service(:cloud_formation, 'CloudFormation')
    service(:cloud_watch,     'CloudWatch')
    service(:compute,         'Compute')
    service(:data_pipeline,   'DataPipeline')
    service(:dns,             'DNS')
    service(:dynamodb,        'DynamoDB')
    service(:elasticache,     'Elasticache')
    service(:ecs,             'ECS')
    service(:efs,             'EFS')
    service(:elb,             'ELB')
    service(:elbv2,           'ELBV2')
    service(:emr,             'EMR')
    service(:federation,      'Federation')
    service(:glacier,         'Glacier')
    service(:iam,             'IAM')
    service(:kinesis,         'Kinesis')
    service(:kms,             'KMS')
    service(:lambda,          'Lambda')
    service(:rds,             'RDS')
    service(:redshift,        'Redshift')
    service(:ses,             'SES')
    service(:simpledb,        'SimpleDB')
    service(:sns,             'SNS')
    service(:sqs,             'SQS')
    service(:storage,         'Storage')
    service(:sts,             'STS')
    service(:support,         'Support')

    # Transforms hash keys according to the passed mapping or given block
    #
    # ==== Parameters
    # * object<~Hash> - A hash to apply transformation to
    # * mappings<~Hash> - A hash of mappings for keys. Keys of the mappings object should match desired keys of the
    #   object which will be transformed. If object contains values that are hashes or arrays of hashes which should
    #   be transformed as well mappings object's value should be configured with a specific form, for example:
    #   {
    #     :key => {
    #       'Key' => {
    #         :nested_key => 'NestedKey'
    #       }
    #     }
    #   }
    #   This form will transform object's key :key to 'Key'
    #   and transform corresponding value: if it's a hash then its key :nested_key will be transformed into 'NestedKey'
    #   if it's an array of hashes, each hash element of the array will have it's key :nested_key transformed into 'NestedKey'
    # * block<~Proc> - block which is applied if mappings object does not contain key. Block receives key as it's argument
    #   and should return new key as the one that will be used to replace the original one
    # ==== Returns
    # * object<~Hash> - hash containing transformed keys
    #
    def self.map_keys(object, mappings = nil, &block)
      case object
      when ::Hash
        object.reduce({}) do |acc, (key, val)|
          mapping = mappings[key] if mappings
          new_key, new_value = begin
            if mapping
              case mapping
              when ::Hash
                mapped_key = mapping.keys[0]
                [mapped_key, map_keys(val, mapping[mapped_key], &block)]
              else
                [mapping, map_keys(val, &block)]
              end
            else
              mapped_value = map_keys(val, &block)
              if block_given?
                [block.call(key), mapped_value]
              else
                [key, mapped_value]
              end
            end
          end
          acc[new_key] = new_value
          acc
        end
      when ::Array
        object.map { |item| map_keys(item, mappings, &block) }
      else
        object
      end
    end

    # Maps object keys to aws compatible: underscore keys are transformed in camel case strings
    # with capitalized first word (aka :ab_cd transforms into AbCd). Already compatible keys remain the same
    #
    # ==== Parameters
    # * object<~Hash> - A hash to apply transformation to
    # * mappings<~Hash> - An optional hash of mappings for keys
    # ==== Returns
    # * object<~Hash> - hash containing transformed keys
    #
    def self.map_to_aws(object, mappings = nil)
      map_keys(object, mappings) do |key|
        words = key.to_s.split('_')
        if words.length > 1
          words.collect(&:capitalize).join
        else
          words[0].split(/(?=[A-Z])/).collect(&:capitalize).join
        end
      end
    end

    # Maps object keys from aws to ruby compatible form aka snake case symbols
    #
    # ==== Parameters
    # * object<~Hash> - A hash to apply transformation to
    # * mappings<~Hash> - An optional hash of mappings for keys
    # ==== Returns
    # * object<~Hash> - hash containing transformed keys
    #
    def self.map_from_aws(object, mappings = nil)
      map_keys(object, mappings) { |key| key.to_s.split(/(?=[A-Z])/).join('_').downcase.to_sym }
    end

    # Helper function to invert mappings: recursively replaces mapping keys and values.
    #
    # ==== Parameters
    # * mappings<~Hash> - mappings hash
    # ==== Returns
    # * object<~Hash> - inverted mappings
    #
    def self.invert_mappings(mappings)
      mappings.reduce({}) do |acc, (key, val)|
        mapped_key, mapped_value = case val
                                   when ::Hash
                                     [val.keys[0], val.values[0]]
                                   else
                                     [val, nil]
                                   end
        acc[mapped_key] = mapped_value ? { key => invert_mappings(mapped_value) } : key
        acc
      end
    end

    def self.indexed_param(key, values)
      params = {}
      unless key.include?('%d')
        key << '.%d'
      end
      [*values].each_with_index do |value, index|
        if value.respond_to?('keys')
          k = format(key, index + 1)
          value.each do | vkey, vvalue |
            params["#{k}.#{vkey}"] = vvalue
          end
        else
          params[format(key, index + 1)] = value
        end
      end
      params
    end

    def self.serialize_keys(key, value, options = {})
      case value
      when Hash
        value.each do | k, v |
          options.merge!(serialize_keys("#{key}.#{k}", v))
        end
        return options
      when Array
        value.each_with_index do | it, idx |
          options.merge!(serialize_keys("#{key}.member.#{(idx + 1)}", it))
        end
        return options
      else
        return {key => value}
      end
    end

    def self.indexed_request_param(name, values)
      idx = -1
      Array(values).reduce({}) do |params, value|
        params["#{name}.#{idx += 1}"] = value
        params
      end
    end

    def self.indexed_filters(filters)
      params = {}
      filters.keys.each_with_index do |key, key_index|
        key_index += 1
        params[format('Filter.%d.Name', key_index)] = key
        [*filters[key]].each_with_index do |value, value_index|
          value_index += 1
          params[format('Filter.%d.Value.%d', key_index, value_index)] = value
        end
      end
      params
    end

    def self.escape(string)
      string.gsub(/([^a-zA-Z0-9_.\-~]+)/) {
        "%" + $1.unpack("H2" * $1.bytesize).join("%").upcase
      }
    end

    def self.signed_params_v4(params, headers, options={})
      date = Fog::Time.now

      params = params.merge('Version' => options[:version])

      headers = headers.merge('Host' => options[:host], 'x-amz-date' => date.to_iso8601_basic)
      headers['x-amz-security-token'] = options[:aws_session_token] if options[:aws_session_token]
      query = options[:query] || {}

      if !options[:body]
        body = ''
        for key in params.keys.sort
          unless (value = params[key]).nil?
            body << "#{key}=#{escape(value.to_s)}&"
          end
        end
        body.chop!
      else
        body = options[:body]
      end

      headers['Authorization'] = options[:signer].sign({:method => options[:method], :headers => headers, :body => body, :query => query, :path => options[:path]}, date)

      return body, headers
    end

    def self.signed_params(params, options = {})
      params.merge!({
        'AWSAccessKeyId'    => options[:aws_access_key_id],
        'SignatureMethod'   => 'HmacSHA256',
        'SignatureVersion'  => '2',
        'Timestamp'         => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
        'Version'           => options[:version]
      })

      params.merge!({
        'SecurityToken'     => options[:aws_session_token]
      }) if options[:aws_session_token]

      body = ''
      for key in params.keys.sort
        unless (value = params[key]).nil?
          body << "#{key}=#{escape(value.to_s)}&"
        end
      end
      string_to_sign = "POST\n#{options[:host]}:#{options[:port]}\n#{options[:path]}\n" << body.chop
      signed_string = options[:hmac].sign(string_to_sign)
      body << "Signature=#{escape(Base64.encode64(signed_string).chomp!)}"

      body
    end

    def self.parse_security_group_options(group_name, options)
      options ||= Hash.new
      if group_name.is_a?(Hash)
        options = group_name
      elsif group_name
        if options.key?('GroupName')
          raise Fog::Compute::AWS::Error, 'Arguments specified both group_name and GroupName in options'
        end
        options = options.clone
        options['GroupName'] = group_name
      end
      name_specified = options.key?('GroupName') && !options['GroupName'].nil?
      group_id_specified = options.key?('GroupId') && !options['GroupId'].nil?
      unless name_specified || group_id_specified
        raise Fog::Compute::AWS::Error, 'Neither GroupName nor GroupId specified'
      end
      if name_specified && group_id_specified
        options.delete('GroupName')
      end
      options
    end

    def self.json_response?(response)
      return false unless response && response.headers
      response.get_header('Content-Type') =~ %r{application/.*json.*}i ? true : false
    end

    def self.regions
      @regions ||= ['ap-northeast-1', 'ap-northeast-2', 'ap-southeast-1', 'ap-southeast-2', 'eu-central-1', 'ca-central-1', 'eu-west-1', 'eu-west-2', 'us-east-1', 'us-east-2', 'us-west-1', 'us-west-2', 'sa-east-1', 'cn-north-1', 'us-gov-west-1', 'ap-south-1']
    end

    def self.validate_region!(region, host=nil)
      if (!host || host.end_with?('.amazonaws.com')) && !regions.include?(region)
        raise ArgumentError, "Unknown region: #{region.inspect}"
      end
    end
  end
end
