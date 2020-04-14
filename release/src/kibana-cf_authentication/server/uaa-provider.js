const uuid = require('uuid')

module.exports = (server, config, cache) => {
  const uaaProvider = {
    protocol: 'oauth2',
    auth: config.get('authentication.authorization_uri'),
    token: config.get('authentication.token_uri'),
    scope: ['openid', 'oauth.approvals', 'scim.userids', 'cloud_controller.read'],
    /*
      Function for obtaining user profile
      (is called after obtaining user access token in bell/lib/oauth.js v2 function).
      Here we get user account details (profile, orgs/spaces)
      and store it and user credentials (Oauth tokens) in the cache.
      We use generated session_id as a key when storing user data in the cache.
     */
    profile: async (credentials, params, get) => {
      server.log(
        ['debug', 'authentication'],
        JSON.stringify({ credentials, params })
      )

      const account = {}

      // generate user session_id, set it to auth credentials
      credentials.session_id = uuid.v1()

      try {
        const profile = await get(config.get('authentication.account_info_uri'))

        server.log(['debug', 'authentication'], JSON.stringify({ profile }))

        account.profile = {
          id: profile.id,
          username: profile.username,
          displayName: profile.name,
          email: profile.email,
          raw: profile,
          isAdmin: false,
          scopes: []
        }

        // get user orgs
        const orgs = await get(config.get('authentication.organizations_uri'))

        server.log(['debug', 'authentication', 'orgs'], JSON.stringify(orgs))

        account.orgIds = orgs.resources.map((resource) => {
          return resource.metadata.guid
        })
        account.orgs = orgs.resources.map((resource) => {
          return resource.entity.name
        })

        // get user spaces
        const spaces = await get(config.get('authentication.spaces_uri'))

        server.log(['debug', 'authentication', 'spaces'], JSON.stringify(spaces))

        account.spaceIds = spaces.resources.map((resource) => {
          return resource.metadata.guid
        })

        account.spaces = spaces.resources.map((resource) => {
          return resource.entity.name
        })

        account.isAdmin = false
        const systemOrg = config.get('authentication.cf_system_org')
        server.log(['debug', 'authentication', 'systemOrg'], 'System Org = ' + systemOrg)

        const useScopes = (systemOrg === "use-oauth-scopes")

        if (useScopes) {
          // get user scopes
          const userDetails = await get(config.get('authentication.self_info_uri') + profile.user_id)
          account.scopes = userDetails.groups.map(g => g.display)
          server.log(['debug', 'scopes'], JSON.stringify(account.scopes))

          const adminScopes = ["cloud_controller.admin","cloud_controller.admin_read_only","cloud_controller.global_auditor"]
          for (const adminScope of adminScopes) {
            server.log(['debug', 'helper', 'isAdmin'], 'Checking to see if ' + adminScope + ' is in ' + JSON.stringify(account.scopes))
            account.isAdmin = (account.scopes.indexOf(adminScope) !== -1)

            if (account.isAdmin) {
              break
            }
          }
        } else {
          account.isAdmin = account.orgs.indexOf(systemOrg) !== -1
        }

        // store user data in the cache
        await cache.set(credentials.session_id, { credentials, account }, 0)
      } catch (error) {
        server.log(['error', 'authentication', 'session:set'], JSON.stringify(error))
      }
    }
  }

  return uaaProvider
}
