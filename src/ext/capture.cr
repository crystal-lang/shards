require "wait_group"

class Process
  class FailedCommandError < Exception
    getter result : Result

    def initialize(message, @result : Result)
      super(message)
    end
  end

  struct Result
    getter status : Status

    def initialize(@status : Status, @stdout : String?, @stderr : String?)
    end

    def stdout : String
      @stdout || ""
    end

    def stdout? : String?
      @stdout
    end

    def stderr : String
      @stderr || ""
    end

    def stderr? : String?
      @stderr
    end
  end

  def self.capture_result(command : String, args : Enumerable(String)? = nil, env : Env = nil, clear_env : Bool = false,
                          input : Stdio = Redirect::Close, output : Stdio = Redirect::Pipe, error : Stdio = Redirect::Pipe, chdir : Path | String? = nil) : Result
    captured_error = nil
    wg = WaitGroup.new
    process = Process.new(command, args, env: env, clear_env: clear_env, input: input, output: Redirect::Pipe, error: error, chdir: chdir)
    if error == Redirect::Pipe
      wg.spawn do
        captured_error = process.error.gets_to_end
      rescue
        # silence exceptions
      end
    end

    if output == Redirect::Pipe
      captured_output = process.output.gets_to_end
    end

    process.close
    status = process.wait
    wg.wait

    Result.new(status, captured_output, captured_error)
  end

  def self.capture(command : String, args : Enumerable(String)? = nil, env : Env = nil, clear_env : Bool = false,
                   input : Stdio = Redirect::Close, error : Stdio = Redirect::Pipe, chdir : Path | String? = nil) : String
    result = capture_result(command, args, env: env, clear_env: clear_env, input: input, error: error, chdir: chdir)

    unless result.status.success?
      raise FailedCommandError.new("Failed command: \"#{command.inspect_unquoted} #{args.join(" ", &.inspect_unquoted)}", result)
    end

    result.stdout
  end
end

def expect_failure(result : Process::Result)
  result.status.success?.should be_false, failure_message: "Expected process status to be failure: #{result}"
  result
end

def expect_success(result : Process::Result)
  result.status.success?.should be_true, failure_message: "Expected process status to be success: #{result}"
  result
end
