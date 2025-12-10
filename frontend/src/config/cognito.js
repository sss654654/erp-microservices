export const cognitoConfig = {
  region: import.meta.env.VITE_COGNITO_REGION || 'ap-northeast-2',
  userPoolId: import.meta.env.VITE_COGNITO_USER_POOL_ID || '',
  userPoolWebClientId: import.meta.env.VITE_COGNITO_CLIENT_ID || '',
};
