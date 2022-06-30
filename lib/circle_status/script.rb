module CircleStatus
  class Script
    def run
      config

      puts "Status: #{latest_build_status.upcase.white}"
      puts "Successes: #{successes.size.to_s.green}"
      puts "Failures: #{failures.size.to_s.red}"
      puts "Failing specs: #{failing_files.join(' ').red}"
      puts "Details: #{latest_build_url}"
      puts
      puts "Pending builds: #{pending_builds.size}"
      pending_builds.map do |pending|
        puts " - #{pending['status']}: #{pending['build_url']}"
      end
    rescue ProjectError => e
      puts "Circle Status failure: #{e.message}"
    end

    def config
      token = ENV.fetch('CIRCLE_CI_TOKEN')
      raise ProjectError, 'no CIRCLE_CI_TOKEN ENV var' if token.nil?
      CircleCi.configure do |config|
        config.token = token
      end
    end

    def builds
      @builds ||= begin
        builds = project.recent_builds_branch(branch).body
        raise ProjectError, 'no builds for this repository' if builds.empty?

        builds
      end
    end

    def project
      CircleCi::Project.new(user_name, repo_name)
    end

    def latest_build
      @latest_build ||= begin
        build = builds.find { |build| %w(failed success).include?(build['status']) }
        fail ProjectError, 'no builds for this branch yet' if build.nil?
        build
      end
    end

    def pending_builds
      @builds.select { |build| build['outcome'].nil? }
    end

    def latest_build_status
      latest_build['status']
    end

    def latest_build_url
      latest_build['build_url']
    end

    def tests
      @tests ||= CircleCi::Build.tests(user_name, repo_name, latest_build['build_num']).body
    end

    def successes
      @sucesses ||= split_tests.first
    end

    def failures
      @failures ||= split_tests.last
    end

    def split_tests
      @split_tests ||= tests['tests'].partition { |test| test['result'] != 'failure' }
    end

    def failing_files
      @failing_files ||= failures.map { |test| test['file'] }.uniq.sort
    end

    def user_name
      remote_url[/github.com[\/:](?<user>.+)?\//, :user]
    end

    def repo_name
      remote_url[/.+\/(?<repo>.+).git/, :repo]
    end

    def remote_url
      origin_remote.url
    end

    def origin_remote
      @origin_remote ||= git.remotes.find { |r| r.name == 'origin' }
    end

    def branch
      git.current_branch
    end

    def git
      @git ||= Git.open(Dir.pwd)
    end
  end
end
