import { useState } from 'react';
import { motion } from 'framer-motion';
import { Link, useNavigate } from 'react-router-dom';
import { Button } from '../components/ui/Button';
import { Card } from '../components/ui/Card';
import { Briefcase } from 'lucide-react';

export function Login() {
  const [isLogin, setIsLogin] = useState(true);
  const [role, setRole] = useState<'candidate' | 'company' | 'admin'>('candidate');
  const navigate = useNavigate();

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    navigate(`/dashboard/${role}`);
  };

  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '24px' }}>
      <Link to="/" style={{ position: 'absolute', top: '32px', left: '48px', display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-primary)', fontWeight: 600 }}>
        <Briefcase size={24} color="var(--primary-blue)" />
        <span>TalentFlow</span>
      </Link>

      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ type: "spring", stiffness: 300, damping: 25 }}
        style={{ width: '100%', maxWidth: '400px' }}
      >
        <Card>
          <div style={{ textAlign: 'center', marginBottom: '32px' }}>
            <h2 style={{ fontSize: '24px', fontWeight: 600, marginBottom: '8px' }}>
              {isLogin ? 'Welcome back' : 'Create an account'}
            </h2>
            <p style={{ color: 'var(--text-secondary)' }}>
              {isLogin ? 'Enter your details to access your account' : 'Join TalentFlow to start your journey'}
            </p>
          </div>

          <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
            {!isLogin && (
              <div>
                <label className="label">I am a...</label>
                <div style={{ display: 'flex', gap: '8px', background: 'rgba(0,0,0,0.04)', padding: '4px', borderRadius: '12px' }}>
                  {(['candidate', 'company'] as const).map(r => (
                    <button
                      key={r}
                      type="button"
                      onClick={() => setRole(r)}
                      style={{
                        flex: 1,
                        padding: '8px',
                        borderRadius: '8px',
                        fontSize: '14px',
                        fontWeight: 500,
                        backgroundColor: role === r ? 'var(--surface-color)' : 'transparent',
                        boxShadow: role === r ? 'var(--shadow-sm)' : 'none',
                        color: role === r ? 'var(--text-primary)' : 'var(--text-secondary)',
                        transition: 'all 0.2s ease'
                      }}
                    >
                      {r.charAt(0).toUpperCase() + r.slice(1)}
                    </button>
                  ))}
                </div>
              </div>
            )}

            <div>
              <label className="label">Email Address</label>
              <input type="email" className="input" placeholder="name@example.com" required />
            </div>
            
            <div>
              <label className="label">Password</label>
              <input type="password" className="input" placeholder="••••••••" required />
            </div>

            <Button type="submit" style={{ width: '100%', marginTop: '8px', padding: '12px' }}>
              {isLogin ? 'Sign In' : 'Sign Up'}
            </Button>
          </form>

          <div style={{ marginTop: '24px', textAlign: 'center', fontSize: '14px' }}>
            <span style={{ color: 'var(--text-secondary)' }}>
              {isLogin ? "Don't have an account? " : "Already have an account? "}
            </span>
            <button 
              onClick={() => setIsLogin(!isLogin)} 
              style={{ color: 'var(--primary-blue)', fontWeight: 500 }}
            >
              {isLogin ? 'Sign up' : 'Log in'}
            </button>
          </div>
          
          {/* For demo purposes */}
          <div style={{ marginTop: '24px', textAlign: 'center', fontSize: '12px', color: 'var(--text-secondary)', paddingTop: '16px', borderTop: '1px solid var(--border-color)' }}>
            <p>Demo Admin Access</p>
            <button onClick={() => navigate('/dashboard/admin')} style={{ color: 'var(--primary-blue)', fontWeight: 500, marginTop: '4px' }}>
              Login as Admin
            </button>
          </div>
        </Card>
      </motion.div>
    </div>
  );
}
