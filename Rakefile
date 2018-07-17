require 'rubygems'
require 'rake'
require 'rspec/core/rake_task'
require 'puppetlabs_spec_helper/rake_tasks'
require 'puppet-lint'

PuppetLint.configuration.ignore_paths = ["pkg/**/*.pp", "tests/*.pp"]
PuppetLint.configuration.send('disable_80chars')
PuppetLint.configuration.send('disable_documentation')
PuppetLint.configuration.send('disable_class_inherits_from_params_class')
PuppetLint.configuration.send('disable_arrow_on_right_operand_line')
PuppetLint.configuration.send('disable_selector_inside_resource')
task :default => [:spec, :lint]

namespace :validate do
  desc "Validate manifests, templates, and ruby files"
  task :all do
    Dir['manifests/**/*.pp'].each do |manifest|
      sh "puppet parser validate --noop #{manifest}"
    end
    Dir['templates/**/*.erb'].each do |template|
      sh "erb -P -x -T '-' #{template} | ruby -c"
    end
  end
end
