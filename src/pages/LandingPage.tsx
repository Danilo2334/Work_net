import { motion } from 'framer-motion';
import { Card } from '../components/ui/Card';
import { Search, Zap, ShieldCheck } from 'lucide-react';
import { Link } from 'react-router-dom';

const fadeIn = {
  hidden: { opacity: 0, y: 20 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.6, ease: [0.22, 1, 0.36, 1] } }
};

const staggerContainer = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: {
      staggerChildren: 0.1
    }
  }
};

export function LandingPage() {
  return (
    <div style={{ minHeight: '100vh', paddingBottom: '64px' }}>
      <main className="container">
        <motion.section 
          initial="hidden" 
          animate="visible" 
          variants={staggerContainer}
          style={{ paddingTop: '120px', paddingBottom: '80px', textAlign: 'center', maxWidth: '800px', margin: '0 auto' }}
        >
          <motion.h1 variants={fadeIn} style={{ fontSize: '56px', fontWeight: 700, letterSpacing: '-0.02em', lineHeight: 1.1, marginBottom: '24px' }}>
            The future of hiring is <span style={{ color: 'var(--primary-blue)' }}>fluid.</span>
          </motion.h1>
          <motion.p variants={fadeIn} style={{ fontSize: '20px', color: 'var(--text-secondary)', marginBottom: '40px', maxWidth: '600px', margin: '0 auto 40px' }}>
            Connect top talent with innovative companies through a seamless, intelligent, and beautifully designed platform.
          </motion.p>
          <motion.div variants={fadeIn} style={{ display: 'flex', gap: '16px', justifyContent: 'center' }}>
            <Link to="/login" className="btn btn-primary" style={{ padding: '14px 28px', fontSize: '16px' }}>
              I'm a Candidate
            </Link>
            <Link to="/login" className="btn btn-secondary" style={{ padding: '14px 28px', fontSize: '16px' }}>
              I'm a Company
            </Link>
          </motion.div>
        </motion.section>

        <motion.section 
          initial="hidden" 
          whileInView="visible" 
          viewport={{ once: true, margin: "-100px" }}
          variants={staggerContainer}
          className="grid grid-cols-3 gap-6"
          style={{ marginTop: '64px' }}
        >
          <motion.div variants={fadeIn}>
            <Card hoverable style={{ height: '100%' }}>
              <div style={{ width: '48px', height: '48px', borderRadius: '12px', backgroundColor: 'rgba(0, 102, 204, 0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '20px' }}>
                <Search color="var(--primary-blue)" />
              </div>
              <h3 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Intelligent Matching</h3>
              <p style={{ color: 'var(--text-secondary)' }}>Our algorithm connects your skills with the perfect role instantly, without the noise.</p>
            </Card>
          </motion.div>
          <motion.div variants={fadeIn}>
            <Card hoverable style={{ height: '100%' }}>
              <div style={{ width: '48px', height: '48px', borderRadius: '12px', backgroundColor: 'rgba(52, 199, 89, 0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '20px' }}>
                <Zap color="#34c759" />
              </div>
              <h3 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Kanban Tracking</h3>
              <p style={{ color: 'var(--text-secondary)' }}>Visualize your hiring pipeline with our fluid, drag-and-drop Kanban boards for teams.</p>
            </Card>
          </motion.div>
          <motion.div variants={fadeIn}>
            <Card hoverable style={{ height: '100%' }}>
              <div style={{ width: '48px', height: '48px', borderRadius: '12px', backgroundColor: 'rgba(255, 149, 0, 0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '20px' }}>
                <ShieldCheck color="#ff9500" />
              </div>
              <h3 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Verified Entities</h3>
              <p style={{ color: 'var(--text-secondary)' }}>Every company and profile goes through an administrative validation for a trusted network.</p>
            </Card>
          </motion.div>
        </motion.section>
      </main>
    </div>
  );
}
