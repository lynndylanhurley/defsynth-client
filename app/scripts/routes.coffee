angular.module('defsynthApp')
  .config ($stateProvider, $urlRouterProvider, $locationProvider, $sceProvider, $httpProvider) ->
    # default to 404 if state not found
    $urlRouterProvider.otherwise('/404')

    $stateProvider
      .state 'index',
        url: '/'
        templateUrl: 'index.html'
        controller: 'IndexCtrl'

      .state '404',
        url: '/404'
        templateUrl: '404.html'

      .state 'style-guide',
        url: '/style-guide'
        templateUrl: 'style-guide.html'
        controller: 'StyleGuideCtrl'

      .state 'terms',
        url: '/terms'
        templateUrl: 'terms.html'

      .state 'components',
        url: '/components'
        templateUrl: 'pages/components/index.html'
        controller: 'ComponentsCtrl'

      .state 'parts',
        url: '/parts'
        templateUrl: 'parts.html'
        controller: 'PartsCtrl'

      .state 'api-demo',
        url: '/api-demo'
        templateUrl: 'api-demo.html'
        controller: 'ApiDemoCtrl'
