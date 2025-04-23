class PostgresExporter < Formula
  desc "PostgreSQL metric exporter for Prometheus"
  homepage "https://github.com/prometheus-community/postgres_exporter"
  url "https://github.com/prometheus-community/postgres_exporter/archive/refs/tags/v0.17.1.tar.gz"
  sha256 "e1401b3af6e59cd0a880dedf22a5b425840a9edd079efdca235dd7ebe996cd37"
  license "Apache-2.0"

  depends_on "go" => :build
  depends_on "postgresql@17" => :test

  def install
    system "make", "build"
    bin.install "postgres_exporter"
    (bin/"postgres_exporter_brew_services").write <<~SHELL
      #!/bin/bash
      source "#{etc}/postgres_exporter.env"
      exec #{bin}/postgres_exporter $(<#{etc}/postgres_exporter.args)
    SHELL

    touch buildpath/"postgres_exporter.env"
    (buildpath/"postgres_exporter.yml").write("---")
    (buildpath/"postgres_exporter.args").write <<~EOS
      --config.file #{etc}/postgres_exporter.yml
    EOS
    etc.install Dir[buildpath/"postgres_exporter.{env,yml,args}"]
  end

  def caveats
    <<~EOS
      When run from `brew services`, `postgres_exporter` is run from
      `postgres_exporter_brew_services` and uses the flags in:
         #{etc}/postgres_exporter.args
      and the environment defined in:
         #{etc}/postgres_exporter.env
    EOS
  end

  service do
    run opt_bin/"postgres_exporter_brew_services"
    keep_alive true
    log_path var/"log/postgres_exporter.log"
    error_log_path var/"log/postgres_exporter.log"
    working_dir var
  end

  test do
    ENV["LC_ALL"] = "C"

    pg_port = free_port
    pg_bin = Formula["postgresql@17"].opt_bin
    pg_ctl = pg_bin/"pg_ctl"

    datadir = testpath/"postgres"
    system pg_ctl, "init", "-D", datadir

    (datadir/"postgresql.conf").write <<~CONF, mode: "a+"
      port = #{pg_port}
      unix_socket_directories = '#{datadir}'
    CONF

    system pg_ctl, "start", "-D", datadir, "-l", testpath/"postgres.log"
    system pg_bin/"createdb", "-h", datadir, "-p", pg_port.to_s, "postgres_exporter_test"

    # Run postgres_exporter
    exporter_port = free_port
    ENV["DATA_SOURCE_NAME"] = "postgres://localhost:#{pg_port}/postgres_exporter_test?sslmode=disable&host=#{datadir}"

    (testpath/"postgres_exporter.yml").write("---")
    (testpath/"postgres_exporter.args").write <<~EOS
      --config.file #{testpath}/postgres_exporter.yml
      --web.listen-address=127.0.0.1:#{exporter_port}
    EOS
    (testpath/"postgres_exporter_brew_services").write <<~SHELL
      #!/bin/bash
      exec #{bin}/postgres_exporter $(<#{testpath}/postgres_exporter.args)
    SHELL

    chmod "+x", testpath/"postgres_exporter_brew_services"
    pid = spawn(testpath/"postgres_exporter_brew_services")
    begin
      # Give the server time to start
      sleep 2
      assert_match "pg_up 1", shell_output("curl -s http://127.0.0.1:#{exporter_port}/metrics 2>&1")
    ensure
      Process.kill "TERM", pid
      Process.wait pid
    end
  ensure
    system pg_ctl, "stop", "-D", datadir
  end
end
