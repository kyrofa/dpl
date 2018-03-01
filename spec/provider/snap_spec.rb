require 'spec_helper'
require 'dpl/provider/snap'

describe DPL::Provider::Snap do
  after :each do
    remove_test_snap
    FileUtils.rm_rf 'subdir'
  end

  subject :provider do
    described_class.new(
      DummyContext.new, :token => 'test-token', :channel => 'test-channel')
  end

  describe "#install_deploy_dependencies" do
    example do
      provider.install_deploy_dependencies
      expect(ENV['PATH'].split(':')).to include('/snap/bin')
    end
  end

  describe "#check_auth" do
    example "success" do
      allow(Open3).to receive(:capture3).with(
        "snapcraft login --with -", stdin_data: 'test-token').and_return(
          ['test-stdout', 'test-stderr', 0])

      expect(provider).to receive(:log).with("Attemping to login")
      expect(provider).to receive(:log).with("test-stdout")
      provider.check_auth
    end

    example "failure" do
      allow(Open3).to receive(:capture3).with(
        "snapcraft login --with -", stdin_data: 'test-token').and_return(
          ['test-stdout', 'test-stderr', 1])

      expect(provider).to receive(:log).with("Attemping to login")
      expect{provider.check_auth}.to raise_error(
        DPL::Error, "Failed to authenticate: test-stderr")
    end

    example "missing token" do
      allow(Open3).to receive(:capture3).with(
        "snapcraft login --with -", stdin_data: nil).and_return(
          ['test-stdout', 'test-stderr', 1])

      provider.options.delete(:token)
      expect(provider).to receive(:log).with("Attemping to login")
      expect{provider.check_auth}.to raise_error(DPL::Error, "Missing token")
    end
  end

  describe "#push_app" do
    example "existing snap" do
      # Create fake snap
      create_test_snap

      expect(provider.context).to receive(:shell).with(
        "snapcraft push #{test_snap_name} --release=test-channel").and_return(
          true)

      provider.push_app
    end

    example "existing snap subdirectory" do
      # Create fake snap
      create_test_snap 'subdir'

      provider.options[:working_directory] = 'subdir'

      expect(provider.context).to receive(:shell).with(
        "snapcraft push #{test_snap_name} --release=test-channel").and_return(
          true)

      provider.push_app
    end

    example "no existing snap should build one" do
      allow(provider.context).to receive(:shell).with("snapcraft") {
        create_test_snap
      }

      expect(provider).to receive(:log).with(
        "No matching snap found: need to build it")
      expect(provider.context).to receive(:shell).with(
        "snapcraft push #{test_snap_name} --release=test-channel").and_return(
          true)

      provider.push_app
    end

    example "no existing snap and none built should fail" do
      expect(provider).to receive(:log).with(
        "No matching snap found: need to build it")
      expect(provider.context).to receive(:shell).with(
        "snapcraft").and_return(true)
      expect{provider.push_app}.to raise_error(
        DPL::Error, "No snap found matching '*.snap'")
    end

    example "existing snap wrong directory" do
      # Create fake snap in subdirectory, but neglect to specify working
      # directory
      create_test_snap 'subdir'

      expect(provider).to receive(:log).with(
        "No matching snap found: need to build it")
      expect(provider.context).to receive(:shell).with(
        "snapcraft").and_return(true)
      expect{provider.push_app}.to raise_error(
        DPL::Error, "No snap found matching '*.snap'")
    end

    example "missing channel should default to edge" do
      # Create fake snap
      create_test_snap

      provider.options.delete(:channel)

      expect(provider.context).to receive(:shell).with(
        "snapcraft push #{test_snap_name} --release=edge").and_return(true)

      provider.push_app
    end
  end

  private

  def test_snap_name
    "test.snap"
  end

  def create_test_snap(directory = '.')
    FileUtils.mkdir_p directory
    File.open File.join(directory, test_snap_name), "w" do | file |
      file.write("test")
    end
  end

  def remove_test_snap(directory = '.')
    FileUtils.rm_f File.join(directory, test_snap_name)
  end
end
