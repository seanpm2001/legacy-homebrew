class Sbcl < Formula
  desc "Steel Bank Common Lisp system"
  homepage "http://www.sbcl.org/"
  url "https://downloads.sourceforge.net/project/sbcl/sbcl/1.2.14/sbcl-1.2.14-source.tar.bz2"
  sha256 "b9146dd6460c05bca508f6dda83003580911833eedd51dbc09d8eca80b0f5c06"

  head "git://sbcl.git.sourceforge.net/gitroot/sbcl/sbcl.git"

  bottle do
    sha256 "93b1647f07c6bea6e65c2da35b026ebbe8970514787554715c9c029c545692b4" => :yosemite
    sha256 "5531229290137fb58b13e20029ccc89b888bd4dff0ed1dba7b5511a7b1040acb" => :mavericks
    sha256 "61e9d2a7f4cfd8acaeab2e8a290d8816fb60bdd910b57e60ab722ebdf9f8bc3b" => :mountain_lion
  end

  fails_with :llvm do
    build 2334
    cause "Compilation fails with LLVM."
  end

  option "32-bit"
  option "without-threads", "Build SBCL without support for native threads"
  option "without-core-compression", "Build SBCL without support for compressed cores and without a dependency on zlib"
  option "with-ldb", "Include low-level debugger in the build"
  option "with-internal-xref", "Include XREF information for SBCL internals (increases core size by 5-6MB)"

  # Current binary versions are listed at http://sbcl.sourceforge.net/platform-table.html

  resource "bootstrap64" do
    url "https://downloads.sourceforge.net/project/sbcl/sbcl/1.1.8/sbcl-1.1.8-x86-64-darwin-binary.tar.bz2"
    sha256 "729054dc27d6b53bd734eac4dffeaa9e231e97bdbe4927d7a68c8f0210cad700"
  end

  resource "bootstrap32" do
    url "https://downloads.sourceforge.net/project/sbcl/sbcl/1.1.6/sbcl-1.1.6-x86-darwin-binary.tar.bz2"
    sha256 "5801c60e2a875d263fccde446308b613c0253a84a61ab63569be62eb086718b3"
  end

  patch :p0 do
    url "https://trac.macports.org/export/88830/trunk/dports/lang/sbcl/files/patch-base-target-features.diff"
    sha256 "e101d7dc015ea71c15a58a5c54777283c89070bf7801a13cd3b3a1969a6d8b75"
  end

  patch :p0 do
    url "https://trac.macports.org/export/88830/trunk/dports/lang/sbcl/files/patch-make-doc.diff"
    sha256 "7c21c89fd6ec022d4f17670c3253bd33a4ac2784744e4c899c32fbe27203d87e"
  end

  patch :p0 do
    url "https://trac.macports.org/export/88830/trunk/dports/lang/sbcl/files/patch-posix-tests.diff"
    sha256 "06908aaa94ba82447d64cf15eb8e011ac4c2ae4c3050b19b36316f64992ee21d"
  end

  patch :p0 do
    url "https://trac.macports.org/export/88830/trunk/dports/lang/sbcl/files/patch-use-mach-exception-handler.diff"
    sha256 "089b8fdc576a9a32da0b2cdf2b7b2d8bfebf3d542ac567f1cb06f19c03eaf57d"
  end

  def write_features
    features = []
    features << ":sb-thread" if build.with? "threads"
    features << ":sb-core-compression" if build.with? "core-compression"
    features << ":sb-ldb" if build.with? "ldb"
    features << ":sb-xref-for-internals" if build.with? "internal-xref"

    File.open("customize-target-features.lisp", "w") do |file|
      file.puts "(lambda (list)"
      features.each do |f|
        file.puts "  (pushnew #{f} list)"
      end
      file.puts "  list)"
    end
  end

  def install
    write_features

    # Remove non-ASCII values from environment as they cause build failures
    # More information: http://bugs.gentoo.org/show_bug.cgi?id=174702
    ENV.delete_if do |_, value|
      ascii_val = value.dup
      ascii_val.force_encoding("ASCII-8BIT") if ascii_val.respond_to? :force_encoding
      ascii_val =~ /[\x80-\xff]/n
    end

    bootstrap = (build.build_32_bit? || !MacOS.prefer_64_bit?) ? "bootstrap32" : "bootstrap64"
    resource(bootstrap).stage do
      # We only need the binaries for bootstrapping, so don't install anything:
      command = "#{Dir.pwd}/src/runtime/sbcl"
      core = "#{Dir.pwd}/output/sbcl.core"
      xc_cmdline = "#{command} --core #{core} --disable-debugger --no-userinit --no-sysinit"

      cd buildpath do
        ENV["SBCL_ARCH"] = "x86" if build.build_32_bit?
        Pathname.new("version.lisp-expr").write('"1.0.99.999"') if build.head?
        system "./make.sh", "--prefix=#{prefix}", "--xc-host=#{xc_cmdline}"
      end
    end

    ENV["INSTALL_ROOT"] = prefix
    system "sh", "install.sh"
  end

  test do
    (testpath/"simple.sbcl").write <<-EOS.undent
      (write-line (write-to-string (+ 2 2)))
    EOS
    output = shell_output("#{bin}/sbcl --script #{testpath}/simple.sbcl")
    assert_equal "4", output.strip
  end
end
