# Using 3scale API Gateway on Red Hat OpenShift

This tutorial describes how to use APIcast v2 &ndash; the dockerized 3scale API Gateway that is packaged for easy installation and operation on Red Hat OpenShift v3.

## Tutorial Prerequisites

To follow the tutorial steps below, you'll first need to address the following prerequisites to setup your 3scale account and configure OpenShift:

### 3scale account configuration

These steps will guide you to finding information you will need later to complete the tutorial steps: your _3scale Admin URL_, the _Access Token_, and the _Private Base URL_ of your API.

You should have a 3scale API provider account (you can sign up for a free trial <a href="https://www.3scale.net/signup/">here</a>) and have an API configured in the 3scale Admin Portal. If you do not have an API running and configured in your 3scale account, please follow the instructions in our <a href="https://support.3scale.net/guides/quickstart">Quickstart</a> to do so.

Log in to your 3scale Admin Portal with the URL provided to you. It will look something like this: `https://MYDOMAIN-admin.3scale.net`

#### Create an access token

You will need to create an _Access Token_ that the API gateway will use to download the configuration from your Admin Portal.
Navigate to the **Personal Settings** (top-right), select the **Tokens** tab and click on **Add Access Token**.

Specify a name for the token, select _Account Management API_ as Scope, select the Permission (_Read Only_ will be enough) and click on **Create Access token**.

When the token is generated, make sure you copy it somewhere, as you won't be able to see it again. Later in this tutorial we refer to this token as *ACCESS_TOKEN*.

**Warning**: Keep your _Access Token_ private. Do not share it with anyone and do not put into code repositories or into any document that may reveal it to others. However, in case you suspect unauthorized use of the token, you can always revoke access by deleting the token.

In the 3scale Admin Portal you should either have an API of your own running and configured or use the Echo API that was setup by the onboarding wizard. This tutorial will use the Echo API as an example.

#### Configure your API integration

Navigate to the **Dashboard > API** tab, if you have more than one API in your account, select the API you want to manage with the API Gateway. Select the **Integration** link at top-left.

You need to make sure that the _Deployment Option_ is set to _Self-managed Gateway_. If it's not the case, click on **edit integration settings** on the top right corner of the integration page and select _Self-managed Gateway_ as production deployment option. For authentication this tutorial uses _API Key (user\_key)_ mode, specified in query parameters, so it is recommended that you select this mode as well.

If you're setting this up for the first time, you'll need to test the integration to confirm that your private (unmanaged) API is working before proceeding. If you've already configured your API and sent test traffic, feel free to skip this step.

<img src="https://support.3scale.net/images/screenshots/guides-openshift-private-base-url.png" alt="Private base URL">

In the screenshot above, this API is configured to use the 3scale provided Echo API to help you get started. You can use this or configure the _Private Base URL_ to refer to your real API.

Test your private (unmanaged) API is working using this _curl_ command:

    curl https://echo-api.3scale.net:443/

You should get a response similar to this:

    {
      "method": "GET",
      "path": "/",
      "args": "",
      "body": "",
      "headers": {
        "HTTP_VERSION": "HTTP/1.1",
        "HTTP_HOST": "echo-api.3scale.net",
        "HTTP_USER_AGENT": "curl/7.43.0",
        "HTTP_ACCEPT": "*/*",
        "HTTP_X_FORWARDED_FOR": "10.1.0.154",
        "HTTP_CONNECTION": "close"
    }

Once you've confirmed that your API is working, scroll down to the bottom of the **Staging** section where you can see a sample _curl_ command:

    curl "https://XXX.staging.apicast.io:443/?user_key=YOUR_USER_KEY"

**Note**: Note down *YOUR_USER_KEY* to use later to authenticate to your managed API.

Now, scroll down to the section **Production: Self-managed Gateway** at the bottom of the Integration page. You need to add a _Public Base URL_ appropriate for this API or Service, that will be the URL of your API gateway. In case you have multiple API services, you will need to set this _Public Base URL_ appropriately for each service. In this example we will use `http://gateway.openshift.demo:80` as _Public Base URL_, but typically it will be something like `https://api.yourdomain.com:443`, on the domain that you manage (`yourdomain.com`).

### Setup OpenShift

For production deployments you can follow the [instructions for OpenShift installation](https://docs.openshift.com/container-platform/3.3/install_config/install/quick_install.html). In order to get started quickly in development environments, there are many ways you can install OpenShift:
- Using `oc cluster up` command &ndash; https://github.com/openshift/origin/blob/v3.10.0/docs/cluster_up_down.md (used in this tutorial, with detailed instructions for Mac and Windows in addition to Linux which we cover here)

In this tutorial the OpenShift cluster will be installed using:

- CentOS 7
- Docker v1.10.3
- Openshift Origin command line interface (CLI) - v1.3.1

1. Install Docker

  For CentOS you can use the following commands to install Docker:

  ```bash
  sudo yum -y update
  sudo yum -y install docker docker-registry
  ```

  For other operating systems please refer to the Docker documentation on:
    - [Installing Docker on Linux distributions](https://docs.docker.com/engine/installation/linux/)
    - [Docker for Mac](https://docs.docker.com/docker-for-mac/)
    - [Docker for Windows](https://docs.docker.com/docker-for-windows/)

2. Add an insecure registry of `172.30.0.0/16`

  In CentOS configure the Docker daemon with these steps:
   - Edit the `/etc/sysconfig/docker` file and add or uncomment the following line:
     ```
     INSECURE_REGISTRY='--insecure-registry 172.30.0.0/16'
     ```

   - After editing the config, restart the Docker daemon.
     ```
     $ sudo systemctl restart docker
     ```

  If you are using another operating system, follow the instructions for [Docker for Mac](https://github.com/openshift/origin/blob/v3.10.0/docs/cluster_up_down.md#macos-with-docker-for-mac), [Docker for Windows](https://github.com/openshift/origin/blob/v3.10.0/docs/cluster_up_down.md#windows-with-docker-for-windows), or check out [Docker documentation](https://docs.docker.com/registry/insecure/) for how to add an insecure registry.

3. Download the client tools release
   [openshift-origin-client-tools-VERSION-linux-64bit.tar.gz](https://github.com/openshift/origin/releases)
   and place it in your path.

    **Note**: Please be aware that the 'oc cluster' set of commands are only available in the 1.3+ or newer releases.

4. Open a terminal with a user that has permission to run Docker commands and run:
  ```
  oc cluster up
  ```

  At the bottom of the output you will find information about the deployed cluster:
  ```
  -- Server Information ...
     OpenShift server started.
     The server is accessible via web console at:
         https://172.30.0.112:8443

     You are logged in as:
         User:     developer
         Password: developer

     To login as administrator:
         oc login -u system:admin
  ```

 Note the IP address that is assigned to your OpenShift server, we will refer to it in the tutorial as `OPENSHIFT-SERVER-IP`.

#### Setting up OpenShift cluster on a remote server

In case you are deploying the OpenShift cluster on a remote server, you will need to explicitly specify a public hostname and a routing suffix on starting the cluster, in order to be able to access to the OpenShift web console remotely.

For example, if you are deploying on an AWS EC2 instance, you should specify the following options:

```bash
oc cluster up --public-hostname=ec2-54-321-67-89.compute-1.amazonaws.com --routing-suffix=54.321.67.89.xip.io
```

where `ec2-54-321-67-89.compute-1.amazonaws.com` is the Public Domain, and `54.321.67.89` is the IP of the instance. You will then be able to access the OpenShift web console at `https://ec2-54-321-67-89.compute-1.amazonaws.com:8443`.

## Tutorial Steps

### Create your APIcast Gateway using a template

1. By default you are logged in as _developer_ and can proceed to the next step.

 Otherwise login into OpenShift using the `oc` command from the OpenShift Client tools you downloaded and installed in the previous step. The default login credentials are _username = "developer"_ and _password = "developer"_:

 ```shell
 oc login https://OPENSHIFT-SERVER-IP:8443
 ```

 **Warning**: You may get a security warning and asked whether you wish to continue with an insecure selection. Enter "yes" to proceed.

 You should see `Login successful.` in the output.

2. Create your project. This example sets the display name as _gateway_

 <pre><code>oc new-project "3scalegateway" --display-name="gateway" --description="3scale gateway demo"</code></pre>

 The response should look like this:

 ```
 Now using project "3scalegateway" on server "https://172.30.0.112:8443".
 ```

 Ignore the suggested next steps in the text output at the command prompt and proceed to the next step below.

3. Create a new Secret to reference your project by replacing *ACCESS_TOKEN* and *MYDOMAIN* with yours.

 <pre><code>oc secret new-basicauth apicast-configuration-url-secret --password=https://ACCESS_TOKEN@MYDOMAIN-admin.3scale.net</code></pre>

 The response should look like this:

 <pre><code>secret/apicast-configuration-url-secret</code></pre>

4. Create an application for your APIcast Gateway from the template, and start the deployment:

 <pre><code>oc new-app -f https://raw.githubusercontent.com/3scale/apicast/master/openshift/apicast-template.yml</code></pre>

 You should see a message indicating _deploymentconfig_ and _service_ have been successfully created.

### Deploying APIcast Gateway

1. Open the web console for your OpenShift cluster in your browser: `https://OPENSHIFT-SERVER-IP:8443/console/`

 **Warning**: You may receive a warning about an untrusted web-site. This is expected, as we are trying to access to the web console through secure protocol, without having configured a valid certificate. While you should avoid this in production environment, for this test setup you can go ahead and create an exception for this address.

2. Login using your _developer_ credentials created or obtained in the _Setup OpenShift_ section above.

 You will see a list of projects, including the _"gateway"_ project you created from the command line above.

 If you do not see your gateway project, you probably created it with a different user and need to assign the policy role to to this user.

3. Click on _"gateway"_ and you will see the _Overview_ tab.

 OpenShift downloaded the code for the APIcast and started the deployment. You may see the message _Deployment #1 running_ when the deployment is in progress.

 When the build completes, the UI will refresh and show two instances of APIcast ( _2 pods_ ) that have been started by OpenShift, as defined in the template.

 Each instance of the APIcast Gateway, upon starting, downloads the required configuration from 3scale using the settings you provided on the **Integration** page of your 3scale Admin Portal.

 OpenShift will maintain two API Gateway instances and monitor the health of both; any unhealthy API Gateway will automatically be replaced with a new one.

4. In order to allow your API gateways to receive traffic, you'll need to create a route. Start by clicking on **Create Route**.

 Enter the same host you set in 3scale above in the section **Public Base URL** (without the _http://_ and without the port) , e.g. `gateway.openshift.demo`, then click the **Create** button.

 Create a new route for every 3scale Service you define.

5. Your API Gateways are now ready to receive traffic.

 OpenShift takes care of load-balancing incoming requests to the route across the two running instances of the API Gateway.

 Test that the API gateway authorizes a valid call to your API, by executing a curl command with your valid *user_key* to the *hostname* that you configured earlier, e.g. :

 <pre><code>curl "http://gateway.openshift.demo/?user_key=YOUR_USER_KEY"</code></pre>

 In case you are running the OpenShift cluster running locally, you will need to add the hostname `gateway.openshift.demo` for your `OPENSHIFT-SERVER-IP` to the _/etc/hosts_ file, for example:
 ```
 172.30.0.112 gateway.openshift.demo
 ```

 Alternatively, you can specify the hostname of the gateway in the `Host` header when making the request:

 ```
 curl "http://OPENSHIFT-SERVER-IP/?user_key=YOUR_USER_KEY" -H "Host: gateway.openshift.demo"
 ```

 This last option will also work in case your OpenShift cluster is deployed on a remote server. Just use the public IP of the machine where OpenShift is deployed, and specify the hostname from the _Public Base URL_ in the `Host` header.

 This way OpenShift and the API gateway will route the request correctly.

6. Test that the API gateway does not authorize an invalid call to your API.

 <pre><code>curl "http://gateway.openshift.demo/?user_key=INVALID_KEY"</code></pre>

7. If you wish to see the logs of the API Gateways you can do so by clicking **Applications > Pods** and then select one of the pods and then selecting **Logs**.

### Applying changes to the APIcast gateway

Of course, your API configuration is not static. In future you may wish to apply changes to it, for example, choose another authentication method, add new methods and metrics, update the mapping rules, or make any other change on the **Integration** page for your API. In this case you will need to redeploy the APIcast gateway to make the changes effective. In order to do this, go to **Applications > Deployments > threescalegw** and click on **Deploy**.

New pods will be created using the updated configuration, and the old ones will be retired. OpenShift supports different deployment strategies, you can learn more about them in the [OpenShift documentation](https://docs.openshift.com/container-platform/3.3/dev_guide/deployments/deployment_strategies.html)

### Multiple services

If you have multiple services (APIs) in 3scale, you will need to configure the routing properly:

1. For each API, go to the **Integration** tab, and in _Production_ section enter the _Public Base URL_ and click on **Update Production Configuration** to save the changes. Make sure you use a different _Public Base URL_ for each API, for example, `http://search-api.openshift.demo` for the service called Search API and `http://video-api.openshift.demo` for Video API.

2. In OpenShift create routes for the gateway service ("threescalegw"): `http://search-api.openshift.demo` and `http://video-api.openshift.demo`. From **Applications > Routes** you can create a new route or modify and existing one. Note that you can't change the hostname for already created routes, but you can delete an existing route and add a new one.

3. You will need to redeploy the gateway to apply the changes you've made in the 3scale admin portal. Go to **Applications > Deployments > threescalegw** and click on **Deploy**.

4. Now you can make calls to both APIs, and they will be routed to either Search API or Video API depending on the hostname. For example:

 ```
 curl "http://search-api.openshift.demo/find?query=openshift&user_key=YOUR_USER_KEY"
 curl "http://video-api.openshift.demo/categories?user_key=YOUR_USER_KEY"
 ```

 In case you are running the OpenShift cluster running locally, in order for the above calls to work properly you will need to add the hostnames for your `OPENSHIFT-SERVER-IP` to the _/etc/hosts_ file:
 ```
 172.30.0.112 search-api.openshift.demo
 172.30.0.112 video-api.openshift.demo
 ```

 In case your OpenShift cluster is hosted remotely, you can specify the host configured in _Public Base URL_ in the `Host` header in order to get it routed corectly by OpenShift and the API gateway:

 ```
 curl "http://YOUR-PUBLIC-IP/find?query=openshift&user_key=YOUR_USER_KEY" -H "Host: search-api.openshift.demo"
 curl "http://YOUR-PUBLIC-IP/categories?user_key=YOUR_USER_KEY" -H "Host: video-api.openshift.demo"
 ```

### Changing APIcast parameters

APIcast v2 gateway has a number of parameters that can enable/disable different features or change the behavior. These parameters are defined in the OpenShift template. You can find the complete list in the template YAML file. The template parameters are mapped to environment variables that will be set for each running pod.

You can specify the values for the parameters when creating a new application with `oc new-app` command using the `-p | --param` argument, for example:

<pre><code>oc new-app -f https://raw.githubusercontent.com/3scale/apicast/master/openshift/apicast-template.yml -p APICAST_LOG_LEVEL=debug</code></pre>

In order to change the parameters for an existing application, you can modify the environment variables values. Go to **Applications > Deployments > threescalegw** and select the _Environment_ tab.

After modifying the values, click on **Save** button at the bottom, and then **Deploy** to apply the changes in the running API Gateway.

## Success!

Your API is now protected by two instances of the Red Hat 3scale API Gateway running on Red Hat OpenShift, following all the configuration that you set up in the 3scale Admin Portal.

## Next Steps

Now that you have an API Gateway up and running on your local machine you can:

1. Explore how to configure access policies for your API, and engage developers with a Developer Portal by following the <a href="https://support.3scale.net/guides/quickstart">Quickstart</a> guide.
2. Run OpenShift V3 on your dedicated datacenter or on your favorite cloud platform using the advanced installation documentation [listed above](#setup-openshift).
3. Register a custom domain name for your API services, and configure your API integration in 3scale Admin Portal, and in OpenShift by adding new routes.
4. Learn more about OpenShift from the [OpenShift documentation](https://docs.openshift.com/container-platform/3.3/welcome/index.html)
