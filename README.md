## API GW Overview Lab

![alt text](https://github.com/cloudhein/API-GW-with-terraform/blob/main/API%20GW.png)

### Testing the API

>The Lambda and Mock resources can be tested in the browser. By default, any URL you enter into your browser performs a GET request (and remember, only our Lambda and Mock resources have the GET method set).

#### How to call sns resources with POST method 

`curl -X POST -G -d 'TopicArn=arn:aws:sns:REGION:ACCOUNT-ID:API-Messages' -d 'Message=Hello!'  https://abc123def.execute-api.ap-southeast-2.amazonaws.com/v1/sns`

***How to call sns resources with Postman***
![alt text](https://github.com/cloudhein/API-GW-with-terraform/blob/main/postman%20.png)

***You will receive an email from SNS containing the message in your Query String***
![alt text](https://github.com/cloudhein/API-GW-with-terraform/blob/main/sns.png)
