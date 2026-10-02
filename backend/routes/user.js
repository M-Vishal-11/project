const express = require('express');
const { getFirestore, admin } = require('../config/firebase');

const router = express.Router();

// Resolve a close contact only when that phone has a real Firebase Auth account.
// The caller must be signed in; the response contains only the UID and display name.
router.post('/resolve-contact', async (req, res) => {
  try {
    const authorization = req.headers.authorization || '';
    const idToken = authorization.startsWith('Bearer ')
      ? authorization.substring(7)
      : null;
    if (!idToken) return res.status(401).json({ success: false, message: 'Sign in first.' });

    await admin.auth().verifyIdToken(idToken);
    let digits = String(req.body.phoneNumber || '').replace(/\D/g, '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.length === 10 && digits.startsWith('0') && digits[1] === '7') {
      digits = `94${digits.substring(1)}`;
    } else if (digits.length === 9 && digits.startsWith('7')) {
      digits = `94${digits}`;
    } else if (digits.length === 10 && /^[6-9]/.test(digits)) {
      digits = `91${digits}`;
    }
    if (!/^(91\d{10}|94\d{9})$/.test(digits)) {
      return res.status(400).json({ success: false, message: 'Enter a valid supported mobile number.' });
    }

    const phoneNumber = `+${digits}`;
    const profiles = await getFirestore()
      .collection('users')
      .where('phoneNumber', '==', phoneNumber)
      .limit(1)
      .get();
    if (profiles.empty) {
      return res.status(404).json({ success: false, message: 'This phone number is not registered in SafeStep yet.' });
    }

    const profile = profiles.docs[0];
    const uid = profile.id;
    if (profile.data().profileComplete !== true) {
      return res.status(404).json({ success: false, message: 'This account has not completed SafeStep setup yet.' });
    }
    try {
      await admin.auth().getUser(uid);
    } catch (_) {
      return res.status(404).json({ success: false, message: 'This SafeStep profile is not linked to an authenticated account.' });
    }
    return res.json({
      success: true,
      uid,
      name: String(profile.data().name || 'SafeStep user'),
    });
  } catch (error) {
    console.error('[CONTACT RESOLVE] Failed:', error.message);
    return res.status(401).json({ success: false, message: 'Could not verify the signed-in account or contact.' });
  }
});

// Validate phone number format
const validatePhoneNumber = (phoneNumber) => {
  // Remove all non-digit characters
  const digits = phoneNumber.replace(/\D/g, '');
  
  // Check if it's a valid Sri Lankan mobile number
  // Sri Lankan mobile numbers start with 7 and are 9 digits long
  if (digits.length === 9 && digits.startsWith('7')) {
    return `tel:94${digits}`;
  }
  
  // Check if it already has country code
  if (digits.length === 12 && digits.startsWith('947')) {
    return `tel:${digits}`;
  }
  
  return null;
};

// GET /api/user/check/:phoneNumber - Check if user exists
router.get('/check/:phoneNumber', async (req, res) => {
  try {
    const { phoneNumber } = req.params;
    
    console.log('\n🔍 [USER CHECK] Starting user check for:', phoneNumber);
    console.log('📋 Request params:', req.params);
    console.log('📄 Request headers:', req.headers);

    // Handle tel: format for phone number
    let formattedPhone;
    if (phoneNumber.startsWith('tel:')) {
      formattedPhone = phoneNumber; // Use as-is if already in tel: format
      console.log('✅ Phone number already in tel: format:', formattedPhone);
    } else {
      // Validate and format phone number if not in tel: format
      formattedPhone = validatePhoneNumber(phoneNumber);
      if (!formattedPhone) {
        console.log('❌ Invalid phone number format:', phoneNumber);
        return res.status(400).json({
          error: 'Invalid phone number format',
          code: 'INVALID_PHONE_NUMBER',
          message: 'Please provide a valid Sri Lankan mobile number or tel: format'
        });
      }
      console.log('✅ Formatted phone number:', formattedPhone);
    }

    const db = getFirestore();
    
    console.log('🔍 Searching for user with phone number:', formattedPhone);
    console.log('📊 Database connection established');
    
    // Check if user exists in users collection
    console.log('🔍 Querying users collection...');
    const userQuery = await db.collection('users')
      .where('phoneNumber', '==', formattedPhone)
      .limit(1)
      .get();

    console.log('📊 Query results count:', userQuery.size);
    console.log('📊 Query empty?', userQuery.empty);
    
    if (!userQuery.empty) {
      const userData = userQuery.docs[0].data();
      console.log('✅ Found user data:', JSON.stringify(userData, null, 2));
    }
    
    // If no exact match, try alternative formats
    if (userQuery.empty) {
      console.log('🔍 No exact match found, trying alternative formats...');
      
      // Try without tel: prefix
      const altFormattedPhone = formattedPhone.replace('tel:', '');
      console.log('🔍 Trying alternative format 1 (without tel:):', altFormattedPhone);
      const altQuery1 = await db.collection('users')
        .where('phoneNumber', '==', altFormattedPhone)
        .limit(1)
        .get();
      
      console.log('📊 Alternative format 1 (without tel:) results:', altQuery1.size);
      
      if (!altQuery1.empty) {
        const userData = altQuery1.docs[0].data();
        console.log('✅ Found user with alternative format 1');
        
        res.json({
          success: true,
          exists: true,
          userData: {
            name: userData.name,
            email: userData.email,
            dateOfBirth: userData.dateOfBirth,
            createdAt: userData.createdAt,
            lastLoginAt: userData.lastLoginAt,
            profileComplete: userData.profileComplete || false,
          },
          foundWithFormat: 'without_tel_prefix'
        });
        return;
      }
      
      // Try with + prefix
      const altFormattedPhone2 = formattedPhone.replace('tel:', '+');
      console.log('🔍 Trying alternative format 2 (with +):', altFormattedPhone2);
      const altQuery2 = await db.collection('users')
        .where('phoneNumber', '==', altFormattedPhone2)
        .limit(1)
        .get();
      
      console.log('📊 Alternative format 2 (with +) results:', altQuery2.size);
      
      if (!altQuery2.empty) {
        const userData = altQuery2.docs[0].data();
        console.log('✅ Found user with alternative format 2');
        
        res.json({
          success: true,
          exists: true,
          userData: {
            name: userData.name,
            email: userData.email,
            dateOfBirth: userData.dateOfBirth,
            createdAt: userData.createdAt,
            lastLoginAt: userData.lastLoginAt,
            profileComplete: userData.profileComplete || false,
          },
          foundWithFormat: 'with_plus_prefix'
        });
        return;
      }
      
      // Try searching in client_mappings collection as well
      console.log('🔍 Checking client_mappings collection...');
      console.log('🔍 Searching client_mappings with phone:', formattedPhone);
      const clientQuery = await db.collection('client_mappings')
        .where('phoneNumber', '==', formattedPhone)
        .limit(1)
        .get();
      
      console.log('📊 Client mappings results:', clientQuery.size);
      console.log('📊 Client mappings empty?', clientQuery.empty);
      
      if (!clientQuery.empty) {
        const clientData = clientQuery.docs[0].data();
        console.log('✅ Found in client_mappings:', clientData);
        
        res.json({
          success: true,
          exists: true,
          userData: {
            clientId: clientData.clientId,
            clientInfo: clientData.clientInfo,
            createdAt: clientData.createdAt,
            lastSeen: clientData.lastSeen,
          },
          foundInCollection: 'client_mappings',
          message: 'User found in client mappings but not in users collection'
        });
        return;
      }
    }

    if (!userQuery.empty) {
      const userData = userQuery.docs[0].data();
      console.log('✅ Returning user data from exact match');
      
      res.json({
        success: true,
        exists: true,
        userData: {
          name: userData.name,
          email: userData.email,
          dateOfBirth: userData.dateOfBirth,
          createdAt: userData.createdAt,
          lastLoginAt: userData.lastLoginAt,
          profileComplete: userData.profileComplete || false,
        },
        foundWithFormat: 'exact_match'
      });
    } else {
      console.log('❌ No user found in any collection or format');
      console.log('📊 Final response: user not found');
      
      res.json({
        success: true,
        exists: false,
        userData: null,
        searchedFormats: [
          formattedPhone,
          formattedPhone.replace('tel:', ''),
          formattedPhone.replace('tel:', '+')
        ],
        searchedCollections: ['users', 'client_mappings']
      });
    }

  } catch (error) {
    console.error('❌ [USER CHECK ERROR] Error occurred:', error.message);
    console.error('📚 Stack trace:', error.stack);
    console.error('📋 Request params:', req.params);
    console.error('📄 Request headers:', req.headers);
    
    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to check user existence',
      debug: {
        errorMessage: error.message,
        timestamp: new Date().toISOString()
      }
    });
  }
});

module.exports = router;
