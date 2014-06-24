angular.module('defsynthApp', [
  'ngSanitize'
  'ngResource'
  'ui.router'
  'mgcrea.ngStrap'
  'angularSpinner'
  'defsynthPartials'
  'defsynth'
  #'newark'
])
  .config ($stateProvider, $urlRouterProvider, $locationProvider, $sceProvider, $httpProvider) ->
    # disable sce
    # TODO: FIX
    $sceProvider.enabled(false)

    # push-state routes
    $locationProvider.html5Mode(true)

    # include underscore string methods
    _.mixin(_.str.exports())

    $httpProvider.defaults.useXDomain = true
