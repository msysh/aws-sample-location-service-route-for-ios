import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';

export class Stack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const apiKeyName = this.node.tryGetContext('apiKeyName') || 'ExampleKey';

    const region = cdk.Stack.of(this).region;

    // -----------------------------
    // Location Service API Key
    // -----------------------------

    new cdk.aws_location.CfnAPIKey(this, 'ApiKey', {
      keyName: apiKeyName,
      restrictions: {
        allowActions: [
          'geo-maps:GetStaticMap',
          'geo-maps:GetTile',
        ],
        allowResources: [
          `arn:aws:geo-maps:${region}::provider/default`
        ],
      },
      noExpiry: true,
    });

    // -----------------------------
    // Cognito Identity Pool
    // -----------------------------

    const idPool = new cdk.aws_cognito.CfnIdentityPool(this, 'CognitoIdPool', {
      allowClassicFlow: false,
      allowUnauthenticatedIdentities: true,
    });

    const idpUnAuthRole = new cdk.aws_iam.Role(this, 'LocationServiceUnAuthRole', {
      assumedBy: new cdk.aws_iam.FederatedPrincipal('cognito-identity.amazonaws.com', {
        "StringEquals": {
          "cognito-identity.amazonaws.com:aud": idPool.ref
        },
        "ForAnyValue:StringLike": {
          "cognito-identity.amazonaws.com:amr": "unauthenticated"
        }
      },
      'sts:AssumeRoleWithWebIdentity'),
      inlinePolicies: {
        'policy': new cdk.aws_iam.PolicyDocument({
          statements:[
            new cdk.aws_iam.PolicyStatement({
              effect: cdk.aws_iam.Effect.ALLOW,
              actions: [
                'geo-routes:CalculateRoutes',
              ],
              resources: [
                `arn:aws:geo-routes:${region}::provider/default`,
              ]
            })
          ]
        })
      }
    });

    new cdk.aws_cognito.CfnIdentityPoolRoleAttachment(this, 'CognitoIdPoolRoleAttachment', {
      identityPoolId: idPool.ref,
      roles: {
        unauthenticated: idpUnAuthRole.roleArn,
      },
    });

    // -----------------------------
    // Output
    // -----------------------------

    new cdk.CfnOutput(this, 'Output-ApiKeyName', {
      description: 'Location Service API Key Name',
      value: apiKeyName,
    });

    new cdk.CfnOutput(this, 'Output-IdentityPoolId', {
      description: 'Cognito Identity Pool ID',
      value: idPool.ref,
    });
  }
}
