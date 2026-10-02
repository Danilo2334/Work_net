import React from 'react';
import { BrowserRouter, Routes, Route, Outlet } from 'react-router-dom';
import { Navbar } from './components/layout/Navbar';
import { LandingPage } from './pages/LandingPage';
import { Login } from './pages/Login';
import { CandidateDashboard } from './pages/candidate/CandidateDashboard';
import { CompanyDashboard } from './pages/company/CompanyDashboard';
import { AdminDashboard } from './pages/admin/AdminDashboard';

function MainLayout() {
  return (
    <>
      <Navbar />
      <Outlet />
    </>
  );
}

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<MainLayout />}>
          <Route index element={<LandingPage />} />
          {/* We will add other non-dashboard routes here */}
        </Route>
        
        <Route path="/login" element={<Login />} />
        
        {/* Dashboard Routes with their own layout (sidebar included within them) */}
        <Route path="/dashboard/candidate/*" element={<CandidateDashboard />} />
        <Route path="/dashboard/company/*" element={<CompanyDashboard />} />
        <Route path="/dashboard/admin/*" element={<AdminDashboard />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
