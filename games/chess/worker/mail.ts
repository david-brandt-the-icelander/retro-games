// Challenge emails, sent through Resend (resend.com) when RESEND_API_KEY and MAIL_FROM are set.
// Without them nothing is sent: the challenge still waits for the friend, who sees it when they
// sign in with that address, and the challenger gets a link to send them themselves.

export interface MailEnv { RESEND_API_KEY?: string; MAIL_FROM?: string }

export const canMail = (env: MailEnv) => Boolean(env.RESEND_API_KEY && env.MAIL_FROM);

const escape = (s: string) => s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

export function challengeMail(fromName: string, fromEmail: string, link: string): { subject: string; text: string; html: string } {
  const who = `${fromName} (${fromEmail})`;
  const subject = `${fromName} invites you to a game of chess`;
  const text = `${who} has invited you to a game of chess on Gambit.\n\nAccept or decline here: ${link}\n\nSign in with Google or GitHub using this email address to play.`;
  const html = `<div style="font-family:Georgia,serif;background:#0b0c0f;color:#ece8df;padding:32px">
<p style="font:600 11px/1 sans-serif;letter-spacing:3px;color:#d9b26b;margin:0">AN INVITATION</p>
<p style="font-style:italic;font-size:30px;margin:8px 0 16px">Gambit</p>
<p style="font-family:sans-serif">${escape(who)} has invited you to a game of chess.</p>
<p><a href="${escape(link)}" style="display:inline-block;background:#d9b26b;color:#17140e;padding:12px 20px;border-radius:10px;text-decoration:none;font:600 15px sans-serif">Accept or decline</a></p>
<p style="font-family:sans-serif;color:#8d919b">Sign in with Google or GitHub using this email address to play.</p></div>`;
  return { subject, text, html };
}

/** Sends an email. Best effort: false when it couldn't be sent. */
export async function sendMail(env: MailEnv, to: string, msg: { subject: string; text: string; html: string }): Promise<boolean> {
  if (!canMail(env)) return false;
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: env.MAIL_FROM, to: [to], subject: msg.subject, text: msg.text, html: msg.html }),
    });
    return res.ok;
  } catch {
    return false;
  }
}
