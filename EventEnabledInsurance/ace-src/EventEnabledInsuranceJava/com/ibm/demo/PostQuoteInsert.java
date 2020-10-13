package com.ibm.demo;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.sql.Types;

import com.ibm.broker.javacompute.MbJavaComputeNode;
import com.ibm.broker.plugin.MbElement;
import com.ibm.broker.plugin.MbException;
import com.ibm.broker.plugin.MbMessage;
import com.ibm.broker.plugin.MbMessageAssembly;
import com.ibm.broker.plugin.MbOutputTerminal;
import com.ibm.broker.plugin.MbUserException;

public class PostQuoteInsert extends MbJavaComputeNode {

	public void evaluate(MbMessageAssembly inAssembly) throws MbException {
		MbOutputTerminal out = getOutputTerminal("out");
		MbOutputTerminal alt = getOutputTerminal("alternate");

		MbMessage inMessage = inAssembly.getMessage();
		MbMessageAssembly outAssembly = null;
		try {
			// create new message as a copy of the input
			MbMessage outMessage = new MbMessage(inMessage);
			outAssembly = new MbMessageAssembly(inAssembly, outMessage);
			// ----------------------------------------------------------
			// Add user code below

			MbElement DataRoot = outMessage.getRootElement().getLastChild().getFirstElementByPath("/JSON/Data");
            // Obtain a java.sql.Connection using a JDBC Type4 datasource
            // This example uses a Policy of type JDBCProviders called "MyJDBCPolicy" in Policy Project "MyPolicies"  
            Connection conn = getJDBCType4Connection("{DefaultPolicies}:PostgresqlPolicy", JDBC_TransactionType.MB_TRANSACTION_AUTO);
            // Example of using the Connection to create a java.sql.Statement 
            Statement stmt = conn.createStatement(ResultSet.TYPE_SCROLL_INSENSITIVE, ResultSet.CONCUR_READ_ONLY);           
            ResultSet rs = stmt.executeQuery("INSERT INTO QUOTES(Name,EMail,Address,USState,LicensePlate) VALUES('" +
                DataRoot.getFirstElementByPath("Name").getValue() + "','" +
                DataRoot.getFirstElementByPath("EMail").getValue() + "','" +
                DataRoot.getFirstElementByPath("Address").getValue() + "','" +
                DataRoot.getFirstElementByPath("USState").getValue() + "','" +
                DataRoot.getFirstElementByPath("LicensePlate").getValue() + "'" +
            ") RETURNING *");
            rs.next();                      
            DataRoot.createElementAsFirstChild(MbElement.TYPE_NAME, "RequestID", rs.getInt("quoteid"));             
            
            
            // To test without access to postgresql, you can comment the user code above here and uncomment the next two lines 
            // MbElement DataRoot = outMessage.getRootElement().getLastChild().getFirstElementByPath("/JSON/Data");
            // DataRoot.createElementAsFirstChild(MbElement.TYPE_NAME, "RequestID", "1");
            // Also uncomment the marked line 11 lines below here!
            
            // Set up the context to carry the HTTP Reply information
            MbElement Destination = outAssembly.getGlobalEnvironment().getRootElement().createElementAsLastChild(MbElement.TYPE_NAME, "Destination", null);
            MbElement GroupScatter = Destination.createElementAsLastChild(MbElement.TYPE_NAME, "GroupScatter", null);
            MbElement Context = GroupScatter.createElementAsLastChild(MbElement.TYPE_NAME, "Context", null);
            MbElement HTTP = Context.createElementAsLastChild(MbElement.TYPE_NAME, "HTTP", null);
            HTTP.createElementAsLastChild(MbElement.TYPE_NAME, "RequestIdentifier",                   
                    outAssembly.getLocalEnvironment().getRootElement().getFirstElementByPath("/Destination/HTTP/RequestIdentifier").getValue());          
            Context.createElementAsLastChild(MbElement.TYPE_NAME, "QuoteID", rs.getInt("quoteid"));
            // To test without access to postgresql, uncomment this next line
            // Context.createElementAsLastChild(MbElement.TYPE_NAME, "QuoteID", "1");
            Context.createElementAsLastChild(MbElement.TYPE_NAME, "Name", DataRoot.getFirstElementByPath("Name").getValue());
            Context.createElementAsLastChild(MbElement.TYPE_NAME, "EMail", DataRoot.getFirstElementByPath("EMail").getValue());                 
            Context.createElementAsLastChild(MbElement.TYPE_NAME, "Address", DataRoot.getFirstElementByPath("Address").getValue());
            Context.createElementAsLastChild(MbElement.TYPE_NAME, "USState", DataRoot.getFirstElementByPath("USState").getValue());
            Context.createElementAsLastChild(MbElement.TYPE_NAME, "LicensePlate", DataRoot.getFirstElementByPath("LicensePlate").getValue());
            
            // Remove fields which don't get sent to the back ends: Name, EMail, Address and USState
            DataRoot.getFirstElementByPath("Name").delete();
            DataRoot.getFirstElementByPath("EMail").delete();
            DataRoot.getFirstElementByPath("Address").delete();
            DataRoot.getFirstElementByPath("USState").delete();
			
			// End of user code
			// ----------------------------------------------------------
		} catch (MbException e) {
			// Re-throw to allow Broker handling of MbException
			throw e;
		} catch (RuntimeException e) {
			// Re-throw to allow Broker handling of RuntimeException
			throw e;
		} catch (Exception e) {
			// Consider replacing Exception with type(s) thrown by user code
			// Example handling ensures all exceptions are re-thrown to be handled in the flow
			throw new MbUserException(this, "evaluate()", "", "", e.toString(),
					null);
		}
		// The following should only be changed
		// if not propagating message to the 'out' terminal
		out.propagate(outAssembly);

	}

	/**
	 * onPreSetupValidation() is called during the construction of the node
	 * to allow the node configuration to be validated.  Updating the node
	 * configuration or connecting to external resources should be avoided.
	 *
	 * @throws MbException
	 */
	@Override
	public void onPreSetupValidation() throws MbException {
	}

	/**
	 * onSetup() is called during the start of the message flow allowing
	 * configuration to be read/cached, and endpoints to be registered.
	 *
	 * Calling getPolicy() within this method to retrieve a policy links this
	 * node to the policy. If the policy is subsequently redeployed the message
	 * flow will be torn down and reinitialized to it's state prior to the policy
	 * redeploy.
	 *
	 * @throws MbException
	 */
	@Override
	public void onSetup() throws MbException {
	}

	/**
	 * onStart() is called as the message flow is started. The thread pool for
	 * the message flow is running when this method is invoked.
	 *
	 * @throws MbException
	 */
	@Override
	public void onStart() throws MbException {
	}

	/**
	 * onStop() is called as the message flow is stopped. 
	 *
	 * The onStop method is called twice as a message flow is stopped. Initially
	 * with a 'wait' value of false and subsequently with a 'wait' value of true.
	 * Blocking operations should be avoided during the initial call. All thread
	 * pools and external connections should be stopped by the completion of the
	 * second call.
	 *
	 * @throws MbException
	 */
	@Override
	public void onStop(boolean wait) throws MbException {
	}

	/**
	 * onTearDown() is called to allow any cached data to be released and any
	 * endpoints to be deregistered.
	 *
	 * @throws MbException
	 */
	@Override
	public void onTearDown() throws MbException {
	}

}
