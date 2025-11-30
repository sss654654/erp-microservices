import { useState, useEffect } from 'react';
import { notificationService } from '../services/notificationService';

function Notifications() {
  const [notifications, setNotifications] = useState([]);

  useEffect(() => {
    notificationService.connect((notification) => {
      setNotifications((prev) => [notification, ...prev].slice(0, 10));
    });

    return () => {
      notificationService.disconnect();
    };
  }, []);

  return (
    <div style={{ padding: '20px', backgroundColor: '#f5f5f5', borderRadius: '8px' }}>
      <h2>🔔 실시간 알림</h2>
      {notifications.length === 0 ? (
        <p style={{ color: '#999' }}>알림이 없습니다.</p>
      ) : (
        <ul style={{ listStyle: 'none', padding: 0 }}>
          {notifications.map((notif, index) => (
            <li
              key={index}
              style={{
                padding: '10px',
                margin: '10px 0',
                backgroundColor: '#fff',
                borderLeft: '4px solid #4CAF50',
                borderRadius: '4px',
                boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
              }}
            >
              <strong>{notif.title || '알림'}</strong>
              <p style={{ margin: '5px 0 0 0', color: '#666' }}>{notif.message}</p>
              <small style={{ color: '#999' }}>
                {new Date(notif.timestamp || Date.now()).toLocaleString('ko-KR')}
              </small>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

export default Notifications;
