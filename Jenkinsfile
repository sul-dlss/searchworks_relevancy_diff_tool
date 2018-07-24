pipeline {
  agent any

  stages {
    stage('Build') {
      steps {
        checkout scm

        sh '''#!/bin/bash -l
        rvm use 2.4.4@seachworks_relevancy_diff --create
        gem install bundler
        bundle install
        '''
      }
    }

    stage('Test') {
      steps {
        sh '''#!/bin/bash -l
        rvm use 2.4.4@seachworks_relevancy_diff
        cat /tmp/solr_log_queries | bundle exec ruby report.rb
        '''
      }
    }
  }
}
