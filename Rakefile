require 'pathname'

def release_version
  return @release_version if @release_version
  version_file = Pathname.new('wincent-icon-util-version.h').read
  version_line = version_file.lines.find do |line|
    line =~ /\A#define\s+WO_INFO_PLIST_VERSION\s+(.+)\s*\z/
  end or raise "could not find version number"
  @release_version = $~[1]
end

desc 'create a Git tag for the current build'
task :tag do
  if release_version=~ /\+\z/
    raise "refusing to tag intermediate (not official release) version " +
          "(version number '#{release_version}' ends in '+')"
  else
    sh "./tag-release.sh #{release_version}"
  end
end

def aws_put src, dst
  sh "aws put #{dst} #{src}"
  sh "aws put #{dst}?acl --public"
end

desc 'upload the current build to Amazon S3'
task :upload do
  # installer package
  aws_put "../../build/Release/wincent-icon-util-#{release_version}.pkg",
          "s3.wincent.com/wincent-icon-util/releases/wincent-icon-util-#{release_version}.pkg"

  # source archive
  aws_put "../../build/Release/wincent-icon-util-#{release_version}-src.tar.bz2",
          "s3.wincent.com/wincent-icon-util/releases/wincent-icon-util-#{release_version}-src.tar.bz"

  # release notes
  aws_put "../../build/Release/wincent-icon-util-#{release_version}-release-notes.txt",
          "s3.wincent.com/wincent-icon-util/releases/wincent-icon-util-#{release_version}-release-notes.txt"
  aws_put "../../build/Release/wincent-icon-util-#{release_version}-detailed-release-notes.txt",
          "s3.wincent.com/wincent-icon-util/releases/wincent-icon-util-#{release_version}-detailed-release-notes.txt"

  # man page
  aws_put "../../build/Release/wincent-icon-util.1.txt",
          "s3.wincent.com/wincent-icon-util/wincent-icon-util.1.txt"
end
