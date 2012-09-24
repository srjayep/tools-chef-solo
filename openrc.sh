#!/bin/bash

# With the addition of Keystone, to use an openstack cloud you should
# authenticate against keystone, which returns a **Token** and **Service
# Catalog**.  The catalog contains the endpoint for all services the
# user/tenant has access to - including nova, glance, keystone, swift.
#
# *NOTE*: Using the 2.0 *auth api* does not mean that compute api is 2.0.  We
# will use the 1.1 *compute api*
export OS_AUTH_URL=https://ks.dfw2.attcompute.com/v2.0/tokens

# With the addition of Keystone we have standardized on the term **tenant**
# as the entity that owns the resources.
export OS_TENANT_ID=a9dffcf2b2494a669e47d7be96c3f153
export OS_TENANT_NAME=sltools-non-prod-dfw2

# In addition to the owning entity (tenant), openstack stores the entity
# performing the action as the **user**.
export OS_USERNAME=zenspider@gmail.com

# With Keystone you pass the keystone password.
export OS_PASSWORD="east-brought-wherever"
