// Test the redirect manually
(function testRedirect() {
  console.log('Testing redirect...');
  setTimeout(() => {
    window.location.href = '/student/dashboard';
  }, 2000);
})();