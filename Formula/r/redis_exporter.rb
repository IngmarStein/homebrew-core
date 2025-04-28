class RedisExporter < Formula
  desc "Prometheus Exporter for ValKey & Redis Metrics"
  homepage "https://github.com/oliver006/redis_exporter"
  url "https://github.com/oliver006/redis_exporter/archive/refs/tags/v1.71.0.tar.gz"
  sha256 "5cc761bfe45c5414d21fc06a6a9081285b4811f5ce7be0d030cf135ad731211f"
  license "MIT"

  depends_on "go" => :build
  depends_on "valkey" => :test

  def install
    system "go", "build", *std_go_args(ldflags: "-s -w")

    (bin/"redis_exporter_brew_services").write <<~SHELL
      #!/bin/bash
      exec #{bin}/redis_exporter $(<#{etc}/redis_exporter.args)
    SHELL

    touch etc/"redis_exporter.args"
  end

  service do
    run opt_bin/"redis_exporter_brew_services"
    keep_alive true
    log_path var/"log/redis_exporter.log"
    error_log_path var/"log/redis_exporter.log"
    working_dir var
  end

  test do
    valkey_port = free_port
    valkey_pid = spawn(Formula["valkey"].bin/"valkey-server", "--port", valkey_port.to_s)

    sleep 2
    # Run redis_exporter
    exporter_port = free_port

    (testpath/"redis_exporter.args").write <<~EOS
      --redis.addr=redis://127.0.0.1:#{valkey_port}
      --web.listen-address=127.0.0.1:#{exporter_port}
    EOS
    (testpath/"redis_exporter_brew_services").write <<~SHELL
      #!/bin/bash
      exec #{bin}/redis_exporter $(<#{testpath}/redis_exporter.args)
    SHELL

    chmod "+x", testpath/"redis_exporter_brew_services"
    exporter_pid = spawn("#{testpath}/redis_exporter_brew_services")
    begin
      sleep 2
      assert_match "redis_up 1", shell_output("curl -s http://127.0.0.1:#{exporter_port}/metrics 2>&1")
    ensure
      Process.kill "TERM", exporter_pid
      Process.wait exporter_pid
    end
  ensure
    Process.kill "TERM", valkey_pid
    Process.wait valkey_pid
  end
end
