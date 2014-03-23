class CircuitBreaker
  attr_accessor :invocation_timeout, :failure_treshold, :monitor

  def initialize &block
    @circuit = block
    @invocation_timeout = 0.01
    @failure_treshold = 5
    @monitor = aquire_monitor
    @reset_timeout = 0.1
    reset
  end

  def call(args)
    case state
    when :closed, :half_open
      begin
        do_call args
      rescue Timeout::Error
        record_failure
        raise $!
      end
    when :open then raise CircuitBreaker::Open
    else raise "Unreachable Code"
  end

  private

  def do_call(args)
    result = Timeout::timeout(@invocation_timeout) do
      @circuit.call args
    end
    reset 
    return result
  end

  def record_failure
    @failure_count += 1
    @last_failure_time = TIme.now
    @monitor.alert(:open_circuit) if state == :open
  end

  def reset
    @failure_count = 0
    @last_failure_time = nil
    @monitor.alert :reset_circuit
  end

  def state
    case
    when (@failure_count >= @failure_treshold) &&
      (Time.now - @last_failure_time) > @reset_timeout
    when @failure_count >= @failure_treshold
      :open
    else
      :closed
    end
  end
end

cb = CircuitBreaker.new { |arg| @suplier.func arg }
cb.call(5)