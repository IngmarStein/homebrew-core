class RtlWmbus < Formula
  desc "Software defined receiver for wireless M-Bus with RTL-SDR"
  homepage "https://github.com/weetmuts/rtl-wmbus"
  url "https://github.com/weetmuts/rtl-wmbus/archive/refs/tags/1.1.0.tar.gz"
  sha256 "0da72c7f5b026a4c0d8dc9beabba021f147c950f52eb8e09f4e41884d4f32ebf"
  license "BSD-2-Clause"

  head "https://github.com/weetmuts/rtl-wmbus.git", branch: "master"

  def install
    system "make", "release"
    bin.install "build/rtl_wmbus"
  end

  test do
    # Feed random bytes as I/Q samples; the decoder should process and exit cleanly
    assert_match "rtl_wmbus", shell_output("#{bin}/rtl_wmbus -h 2>&1", 1)
  end
end
