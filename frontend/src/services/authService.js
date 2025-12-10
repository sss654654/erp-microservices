import { CognitoUserPool, CognitoUser, AuthenticationDetails, CognitoUserAttribute } from 'amazon-cognito-identity-js';
import { cognitoConfig } from '../config/cognito';

const userPool = new CognitoUserPool({
  UserPoolId: cognitoConfig.userPoolId,
  ClientId: cognitoConfig.userPoolWebClientId,
});

export const authService = {
  signUp: (email, password, name, position, department) => {
    return new Promise((resolve, reject) => {
      const attributeList = [
        new CognitoUserAttribute({ Name: 'email', Value: email }),
        new CognitoUserAttribute({ Name: 'name', Value: name }),
        new CognitoUserAttribute({ Name: 'custom:position', Value: position }),
        new CognitoUserAttribute({ Name: 'custom:department', Value: department }),
      ];

      userPool.signUp(email, password, attributeList, null, (err, result) => {
        if (err) reject(err);
        else resolve(result.user);
      });
    });
  },

  signIn: (email, password) => {
    return new Promise((resolve, reject) => {
      const user = new CognitoUser({ Username: email, Pool: userPool });
      const authDetails = new AuthenticationDetails({ Username: email, Password: password });

      user.authenticateUser(authDetails, {
        onSuccess: (result) => {
          const payload = result.getIdToken().decodePayload();
          // employeeId가 없으면 임시로 생성 (1-100 랜덤)
          const employeeId = payload['custom:employeeId'] || Math.floor(Math.random() * 100) + 1;
          resolve({
            token: result.getIdToken().getJwtToken(),
            user: {
              email: payload.email,
              name: payload.name,
              position: payload['custom:position'],
              department: payload['custom:department'],
              employeeId: employeeId,
            },
          });
        },
        onFailure: (err) => reject(err),
      });
    });
  },

  signOut: () => {
    const user = userPool.getCurrentUser();
    if (user) user.signOut();
  },

  getCurrentUser: () => {
    return new Promise((resolve, reject) => {
      const user = userPool.getCurrentUser();
      if (!user) {
        reject(new Error('No user'));
        return;
      }

      user.getSession((err, session) => {
        if (err) {
          reject(err);
          return;
        }

        user.getUserAttributes((err, attributes) => {
          if (err) {
            reject(err);
            return;
          }

          const userData = {};
          attributes.forEach((attr) => {
            userData[attr.Name] = attr.Value;
          });

          // employeeId가 없으면 임시로 생성
          const employeeId = userData['custom:employeeId'] || Math.floor(Math.random() * 100) + 1;

          resolve({
            token: session.getIdToken().getJwtToken(),
            user: {
              email: userData.email,
              name: userData.name,
              position: userData['custom:position'],
              department: userData['custom:department'],
              employeeId: employeeId,
            },
          });
        });
      });
    });
  },

  getToken: () => {
    return new Promise((resolve, reject) => {
      const user = userPool.getCurrentUser();
      if (!user) {
        reject(new Error('No user'));
        return;
      }

      user.getSession((err, session) => {
        if (err) reject(err);
        else resolve(session.getIdToken().getJwtToken());
      });
    });
  },
};
