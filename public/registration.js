function dragon(message) {
  const msgBuffer = new TextEncoder('utf-8').encode(message);
  return crypto.subtle.digest('SHA-512', msgBuffer).then(hashBuffer => {
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const hashHex = hashArray.map(b => ('00' + b.toString(16)).slice(-2)).join('');
    return hashHex;
  });
}

function getForm() {
  return document.getElementById('registration_new_user') || document.getElementById('new_user');
}

function getField(name) {
  return document.getElementById(`registration_user_${name}`) || document.getElementById(`user_${name}`);
}

function handleSubmit(e) {
  e.preventDefault();

  const form = getForm();
  const u1 = getField('account_attributes_username');
  const u2 = getField('username');
  const kobold = getField('kobold');

  if (!!u1 && !!u2 && u1.value.toLowerCase() === u2.value.toLowerCase()) {
    u2.value = u1.value;
  }

  let values = [];

  for (let i = 0; i < form.elements.length; i++) {
    const element = form.elements[i];
    const value = element.value;

    if (!!element && ['text', 'email', 'textarea'].includes(element.type) && !!value) {
      values.push(value.trim().toLowerCase());
    }
  }

  const value = values.join('\u{F0666}');
  dragon(value).then(digest => {
    if (!!kobold) { kobold.value = digest.toUpperCase(); }
    form.submit();
  }, _ => { form.submit(); });
}

function addSubmitHandler() {
  const form = getForm();
  if (!!form) { form.addEventListener('submit', handleSubmit); }
}

window.addEventListener("load", addSubmitHandler);

