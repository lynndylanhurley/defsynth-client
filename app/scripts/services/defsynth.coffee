angular.module('defsynth', ['ngResource', 'ngCookies', 'ui.router'])
  .provider '$defsynth', ->
    $get: [
      '$http'
      '$resource'
      '$q'
      '$location'
      '$cookies'
      '$cookieStore'
      '$state'
      '$window'
      '$timeout'
      '$rootScope'
      ($http, $resource, $q, $location, $cookies, $cookieStore, $state, $window, $timeout, $rootScope) ->
        token: null
        email: null
        user:  {}
        dfd:   null
        modal: null

        # popup timeout
        t: null

        defaultResources:
          components: {uidAttr: 'id'}
          synths:     {uidAttr: 'id'}

        authenticate: (provider) ->
          unless @dfd?
            @dfd = $q.defer()
            popup = @openAuthPopup(provider)
            @requestCredentials(popup)

          @dfd

        openAuthPopup: (provider) ->
          $window.open(CONFIG.apiUrl+'/auth/'+provider+'/login')

        requestCredentials: (popup) ->
          if popup.closed
            console.log '@-->user canceled login'
            @dfd.reject({
              reason: 'unauthorized'
              errors: ['User canceled login.']
            })
            $timeout((=> @dfd = null), 0)
            @modal.hide() if @modal

          else
            popup.postMessage("requestCredentials", '*')

            @t = $timeout((=>
              @requestCredentials(popup)
            ), 500)


        # this will be called before each admin page request.
        validateUser: ->
          unless @dfd?
            @dfd = $q.defer()
            unless @token and @email and @user.id
              # token querystring is present. user most likely just came from
              # registration email link.
              console.log 'cookies', $cookies
              if $location.search().token != undefined
                @token = $location.search().token
                @email = $location.search().email

              # token cookie is present. user is returning to the site, or
              # has refreshed the page.
              else if $cookieStore.get('auth_token')
                @token = $cookieStore.get('auth_token')
                @email = $cookieStore.get('auth_email')

              if @token and @email
                @validateToken()

              # new user session. will redirect to login
              else
                @dfd.reject({
                  reason: 'unauthorized'
                  errors: ['No credentials']
                })

                # wait for reflow, nullify dfd
                $timeout((=> @dfd = null), 0)

            else
              @dfd.resolve({id: @user.id})
              $timeout((=> @dfd = null), 0)

          @dfd.promise

        # confirm that user's auth token is still valid.
        validateToken: () ->
          $http.post(@apiUrl()+'/auth/validate_token', {
            auth_token: @token,
            email: @email
          })
            .success((resp) =>
              console.log 'validate token resp', resp
              @handleValidAuth(resp.data)
            )
            .error((data) =>
              @invalidateTokens()
              @dfd.reject({
                reason: 'unauthorized'
                errors: ['Invalid/expired credentials']
              })

              # wait for reflow, nullify dfd
              $timeout((=> @dfd = null), 0)
            )

        # this service attempts to cache auth tokens, but sometimes we
        # will want to discard saved tokens. examples include:
        # 1. login failure
        # 2. token validation failure
        # 3. user logs out
        invalidateTokens: ->
          # cannot delete user object for scoping reasons. instead, delete
          # all keys on object.
          delete @user[key] for key, val of @user

          # setting these values to null will force the validateToken method
          # to re-validate credentials with api server when validate is called
          @token = null
          @email = null

          # kill cookies, otherwise session will resume on page reload
          delete $cookies['auth_token']
          delete $cookies['auth_email']


        persistTokens: ->
          # store tokens as cookies for returning users / page refresh
          $cookieStore.put('auth_token', @token)
          $cookieStore.put('auth_email', @email)

          # add api token headers to all subsequent requests
          $http.defaults.headers.common['Authorization'] = @buildAuthHeader()


        # generate auth header from auth token + user email
        buildAuthHeader: ->
          "token=#{@token} email=#{@email}"


        # capture input from user, authenticate serverside
        submitLogin: (params) ->
          @dfd = $q.defer()
          $http.post(@apiUrl()+'api/v1/users/sign_in', params)
            .success((resp) =>
              @token = resp.data.auth_token
              @email = resp.data.user.email
              @handleValidAuth(resp.data.user)
            )
            .error((resp) =>
              console.log 'errors', resp
              @invalidateTokens()
              @dfd.reject({
                reason: 'unauthorized'
                errors: ['Invalid credentials']
              })
              # wait for reflow, nullify dfd
              $timeout((=> @dfd = null), 0)
            )
          @dfd.promise


        # destroy auth token on server, destroy user auth credentials
        logOut: ->
          $http.post(@apiUrl()+'/auth/sign_out', {
            email: @email
            token: @auth_token
          })
            .success((resp) => @invalidateTokens())
            .error((resp) => @invalidateTokens())


        handleValidAuth: (user) ->
          _.extend @user, user
          @persistTokens()
          @dfd.resolve({id: @user.id})
          $timeout((=> @dfd = null), 0)


        apiUrl: ->
          unless @_apiUrl?
            if navigator.sayswho.match(/IE/)
              @_apiUrl = '/proxy'
            else
              @_apiUrl = CONFIG.apiUrl

          @_apiUrl

        # return cached ng $resource
        getResource: (resourceName) ->
          @resources()[resourceName]

        getResourceUrl: (resourceName) ->
          @apiUrl() + '/' + resourceName

        # pool of all resources that user can access
        resources: ->
          unless @_resources
            @_resources = {}

            # use perms from server if available, otherwise default to hard coded perms
            perms = if @user.permissions? then @user.permissions else @defaultResources

            # create ng $resource object for each item in permissions hash
            _.each(perms, (v, k) =>
              baseUrl = @getResourceUrl(k)
              @_resources[k] = $resource(
                baseUrl+'/:id',
                {id: '@'+v.uidAttr},
                {
                  update:
                    method: 'PUT'
                  new:
                    method: 'GET'
                    url:    baseUrl+'/new'
                }
              )
            )

          @_resources
    ]

  .run ($defsynth, $timeout, $window, $rootScope, $modal) ->
    # add listeners for popup communication
    $window.addEventListener("message", (ev) =>
      console.log 'received message', ev

      if ev.data.message == 'deliverCredentials'
        ev.source.close()
        $timeout.cancel($defsynth.t)
        console.log 'resp data', ev.data
        $defsynth.token = ev.data.auth_token
        $defsynth.email = ev.data.email
        $defsynth.handleValidAuth(_.omit(ev.data, 'message'))
        $defsynth.modal.hide() if $defsynth.modal
        $rootScope.$digest()

      if ev.data.message == 'authFailure'
        ev.source.close()
        $timeout.cancel($defsynth.t)
        $defsynth.invalidateTokens()
    )

    # bind global user object to auth user
    $rootScope.user = $defsynth.user
    $defsynth.validateUser()

    $rootScope.showAuthDialog = ->
      $defsynth.modal = $modal({
        title: 'Sign in'
        contentTemplate: 'partials/modals/auth-popup.html'
        show: true
      })


    $rootScope.githubLogin = ->
      $defsynth.authenticate('github')

    $rootScope.facebookLogin = ->
      $defsynth.authenticate('facebook')

    $rootScope.googleLogin = ->
      $defsynth.authenticate('google')
