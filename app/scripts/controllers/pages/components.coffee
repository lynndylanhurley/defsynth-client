angular.module('defsynthApp')
  .controller 'ComponentsCtrl', ($scope, $defsynth) ->
    console.log 'components'

    $defsynth.getResource('components').get().$promise.then((resp) ->
      console.log 'resp', resp
      $scope.components = resp.data
      console.log 'components', $scope.components
    )


