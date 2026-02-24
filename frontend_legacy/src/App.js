import { useEffect, useState } from 'react';
import './index.css';
import { supabase } from './supabaseClient'
import Auth from './Auth'
import Account from './Account'

export default function Home() {
  const [session, setSession] = useState(null)

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session)
    })

    supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session)
    })
  }, [])

  return (
    <div className="container" style={{ padding: '50px 0 100px 0' }}>
      {!session ? <Auth /> : <Account key={session.user.id} session={session} />}
    </div>
  )
  // const [data, setData] = useState("");

  // useEffect(() => {
  //   fetch("http://localhost:8000/api/data")
  //     .then(res => res.json())
  //     .then(data => setData(data.message));
  // }, []);

  // return <div>Backend says: {data}</div>;
}
