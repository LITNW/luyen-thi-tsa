import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { supabase, supabaseConfigured } from '../lib/supabase.js';

const AuthContext = createContext(null);
const PROFILE_FIELDS = 'id,email,display_name,user_code,role,status,created_at';

export function AuthProvider({ children }) {
  const [auth, setAuth] = useState({
    session: null,
    user: null,
    profile: null,
    loading: true,
    error: '',
  });

  useEffect(() => {
    let alive = true;

    const syncSession = async (session) => {
      if (!alive) return;
      if (!session?.user) {
        setAuth({ session: null, user: null, profile: null, loading: false, error: '' });
        return;
      }

      setAuth((current) => ({
        ...current,
        session,
        user: session.user,
        loading: true,
        error: '',
      }));

      const { data, error } = await supabase
        .from('profiles')
        .select(PROFILE_FIELDS)
        .eq('id', session.user.id)
        .single();

      if (!alive) return;
      if (error || !data) {
        setAuth({
          session,
          user: session.user,
          profile: null,
          loading: false,
          error: error?.message || 'Tài khoản chưa có hồ sơ trên hệ thống.',
        });
        return;
      }

      setAuth({
        session,
        user: session.user,
        profile: data,
        loading: false,
        error: '',
      });
    };

    if (!supabaseConfigured || !supabase) {
      setAuth({
        session: null,
        user: null,
        profile: null,
        loading: false,
        error: 'Thiếu cấu hình Supabase cho bản Preview. Hãy kiểm tra biến VITE_SUPABASE_URL và VITE_SUPABASE_PUBLISHABLE_KEY.',
      });
      return () => { alive = false; };
    }

    const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => {
      window.setTimeout(() => { void syncSession(session); }, 0);
    });

    supabase.auth.getSession()
      .then(({ data, error }) => {
        if (error) throw error;
        return syncSession(data.session);
      })
      .catch((error) => {
        if (alive) {
          setAuth({
            session: null,
            user: null,
            profile: null,
            loading: false,
            error: error?.message || 'Không thể khôi phục phiên đăng nhập.',
          });
        }
      });

    return () => {
      alive = false;
      listener.subscription.unsubscribe();
    };
  }, []);

  const value = useMemo(() => ({
    ...auth,
    isAdmin: auth.profile?.role === 'admin' && auth.profile?.status === 'active',
    signIn: async (email, password) => {
      if (!supabase) throw new Error('Supabase chưa được cấu hình.');
      const { data, error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) throw error;
      return data;
    },
    signUp: async ({ displayName, email, password }) => {
      if (!supabase) throw new Error('Supabase chưa được cấu hình.');
      if (!displayName.trim() || displayName.trim().length > 80) {
        throw new Error('Tên hiển thị phải có từ 1 đến 80 ký tự.');
      }
      if (password.length < 8) throw new Error('Mật khẩu phải có ít nhất 8 ký tự.');
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: { display_name: displayName.trim() },
          emailRedirectTo: window.location.origin,
        },
      });
      if (error) throw error;
      return data;
    },
    signOut: async () => {
      if (!supabase) return;
      const { error } = await supabase.auth.signOut();
      if (error) throw error;
    },
  }), [auth]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) throw new Error('useAuth phải được dùng bên trong AuthProvider.');
  return value;
}
