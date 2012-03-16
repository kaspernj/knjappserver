# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{knjappserver}
  s.version = "0.0.20"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Kasper Johansen"]
  s.date = %q{2012-03-16}
  s.description = %q{Which supports a lot of undocumented stuff.}
  s.email = %q{k@spernj.org}
  s.executables = ["check_running.rb", "knjappserver_start.rb"]
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]
  s.files = [
    ".document",
    ".rspec",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE.txt",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "bin/check_running.rb",
    "bin/knjappserver_start.rb",
    "knjappserver.gemspec",
    "lib/conf/README",
    "lib/conf/conf_example.rb",
    "lib/conf/conf_vars_example.rb",
    "lib/files/database_schema.rb",
    "lib/files/run/README",
    "lib/include/class_customio.rb",
    "lib/include/class_erbhandler.rb",
    "lib/include/class_httpserver.rb",
    "lib/include/class_httpsession.rb",
    "lib/include/class_httpsession_contentgroup.rb",
    "lib/include/class_httpsession_http_request.rb",
    "lib/include/class_httpsession_http_response.rb",
    "lib/include/class_httpsession_post_multipart.rb",
    "lib/include/class_knjappserver.rb",
    "lib/include/class_knjappserver_cleaner.rb",
    "lib/include/class_knjappserver_cmdline.rb",
    "lib/include/class_knjappserver_errors.rb",
    "lib/include/class_knjappserver_leakproxy_client.rb",
    "lib/include/class_knjappserver_leakproxy_server.rb",
    "lib/include/class_knjappserver_logging.rb",
    "lib/include/class_knjappserver_mailing.rb",
    "lib/include/class_knjappserver_sessions.rb",
    "lib/include/class_knjappserver_threadding.rb",
    "lib/include/class_knjappserver_threadding_timeout.rb",
    "lib/include/class_knjappserver_translations.rb",
    "lib/include/class_knjappserver_web.rb",
    "lib/include/class_log.rb",
    "lib/include/class_log_access.rb",
    "lib/include/class_log_data.rb",
    "lib/include/class_log_data_link.rb",
    "lib/include/class_log_data_value.rb",
    "lib/include/class_log_link.rb",
    "lib/include/class_session.rb",
    "lib/include/gettext_funcs.rb",
    "lib/include/magic_methods.rb",
    "lib/knjappserver.rb",
    "lib/pages/benchmark.rhtml",
    "lib/pages/benchmark_print.rhtml",
    "lib/pages/benchmark_simple.rhtml",
    "lib/pages/benchmark_threadded_content.rhtml",
    "lib/pages/debug_database_connections.rhtml",
    "lib/pages/debug_http_sessions.rhtml",
    "lib/pages/error_notfound.rhtml",
    "lib/pages/logs_latest.rhtml",
    "lib/pages/logs_show.rhtml",
    "lib/pages/spec.rhtml",
    "lib/pages/spec_post.rhtml",
    "lib/pages/spec_test_multiple_clients.rhtml",
    "lib/pages/spec_thread_joins.rhtml",
    "lib/pages/spec_threadded_content.rhtml",
    "lib/pages/tests.rhtml",
    "lib/scripts/benchmark.rb",
    "lib/scripts/knjappserver_cgi.rb",
    "lib/scripts/knjappserver_fcgi.rb",
    "lib/scripts/leakproxy.rb",
    "spec/knjappserver_spec.rb",
    "spec/leakproxy_spec.rb",
    "spec/spec_helper.rb"
  ]
  s.homepage = %q{http://github.com/kaspernj/knjappserver}
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.6.2}
  s.summary = %q{A multi-threadded app-web-server.}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<knjrbfw>, [">= 0"])
      s.add_runtime_dependency(%q<erubis>, [">= 0"])
      s.add_runtime_dependency(%q<mail>, [">= 0"])
      s.add_development_dependency(%q<rspec>, ["~> 2.3.0"])
      s.add_development_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.6.3"])
      s.add_development_dependency(%q<rcov>, [">= 0"])
      s.add_development_dependency(%q<sqlite3>, [">= 0"])
      s.add_development_dependency(%q<json>, [">= 0"])
    else
      s.add_dependency(%q<knjrbfw>, [">= 0"])
      s.add_dependency(%q<erubis>, [">= 0"])
      s.add_dependency(%q<mail>, [">= 0"])
      s.add_dependency(%q<rspec>, ["~> 2.3.0"])
      s.add_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_dependency(%q<jeweler>, ["~> 1.6.3"])
      s.add_dependency(%q<rcov>, [">= 0"])
      s.add_dependency(%q<sqlite3>, [">= 0"])
      s.add_dependency(%q<json>, [">= 0"])
    end
  else
    s.add_dependency(%q<knjrbfw>, [">= 0"])
    s.add_dependency(%q<erubis>, [">= 0"])
    s.add_dependency(%q<mail>, [">= 0"])
    s.add_dependency(%q<rspec>, ["~> 2.3.0"])
    s.add_dependency(%q<bundler>, ["~> 1.0.0"])
    s.add_dependency(%q<jeweler>, ["~> 1.6.3"])
    s.add_dependency(%q<rcov>, [">= 0"])
    s.add_dependency(%q<sqlite3>, [">= 0"])
    s.add_dependency(%q<json>, [">= 0"])
  end
end

